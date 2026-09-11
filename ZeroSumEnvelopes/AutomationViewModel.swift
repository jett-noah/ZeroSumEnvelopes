import Foundation
import SwiftData
import Observation

@Observable
final class AutomationViewModel {
    private var modelContext: ModelContext

    var recurringItems: [RecurringItem] = []

    var draftTitle: String = ""
    var draftType: RecurringItemType = .paycheck
    var draftFrequency: RecurringFrequency = .biweekly
    var draftNextExecutionDate: Date = .now
    var draftTotalAmount: Double = 0
    var draftSplits: [UUID: Double] = [:] // Envelope.id -> fixed dollar amount

    /// Only meaningful when draftType == .transfer — the envelope funds
    /// move OUT of.
    var draftSourceEnvelopeID: UUID?

    /// Non-nil while editing an existing item — saveDraft() updates this
    /// item in place instead of inserting a new one.
    var editingItem: RecurringItem?

    var unallocatedAmount: Double = 0
    var isValidToSave: Bool = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    func refresh() {
        let descriptor = FetchDescriptor<RecurringItem>(
            sortBy: [SortDescriptor(\.nextExecutionDate)]
        )
        recurringItems = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Draft management

    func resetDraft(type: RecurringItemType) {
        editingItem = nil
        draftTitle = ""
        draftType = type
        draftFrequency = type == .paycheck ? .biweekly : .monthly
        draftNextExecutionDate = .now
        draftTotalAmount = 0
        draftSplits = [:]
        draftSourceEnvelopeID = nil
        calculateUnallocatedFunds()
    }

    /// Loads an existing item's values into the draft so it can be edited
    /// in place — saveDraft() will update `item` rather than create a new
    /// RecurringItem.
    func loadDraft(from item: RecurringItem) {
        editingItem = item
        draftTitle = item.title
        draftType = item.type
        draftFrequency = item.frequency
        draftNextExecutionDate = item.nextExecutionDate
        draftTotalAmount = item.totalAmount
        draftSplits = Dictionary(
            uniqueKeysWithValues: item.splits.compactMap { key, value in
                UUID(uuidString: key).map { ($0, value) }
            }
        )
        draftSourceEnvelopeID = item.sourceEnvelopeIDString.flatMap { UUID(uuidString: $0) }
        calculateUnallocatedFunds()
    }

    func setSplit(_ amount: Double, for envelope: Envelope) {
        if amount == 0 {
            draftSplits.removeValue(forKey: envelope.id)
        } else {
            draftSplits[envelope.id] = amount
        }
        calculateUnallocatedFunds()
    }

    /// Sets the source envelope for a draft transfer.
    func setSource(_ envelope: Envelope) {
        draftSourceEnvelopeID = envelope.id
        validateZeroSum()
    }

    func calculateUnallocatedFunds() {
        let allocated = draftSplits.values.reduce(0, +)
        unallocatedAmount = draftTotalAmount - allocated
        validateZeroSum()
    }

    func validateZeroSum() {
        switch draftType {
        case .subscription:
            isValidToSave = draftTotalAmount > 0 && draftSplits.count == 1
        case .paycheck:
            isValidToSave = draftTotalAmount > 0 && abs(unallocatedAmount) < 0.005
        case .transfer:
            guard
                let sourceID = draftSourceEnvelopeID,
                let destinationID = draftSplits.keys.first,
                draftSplits.count == 1
            else {
                isValidToSave = false
                return
            }
            isValidToSave = draftTotalAmount > 0 && destinationID != sourceID
        }
    }

    func quickSweep(to targetEnvelope: Envelope) {
        guard unallocatedAmount != 0 else { return }
        let existing = draftSplits[targetEnvelope.id] ?? 0
        draftSplits[targetEnvelope.id] = existing + unallocatedAmount
        calculateUnallocatedFunds()
    }

    // MARK: - Persistence

    func saveDraft() {
        guard isValidToSave else { return }

        // Automations always take effect at midnight on their scheduled
        // date, regardless of what time of day they happened to be
        // created or edited — the date pickers only show a date, so the
        // stored value shouldn't carry a hidden, invisible time-of-day.
        let normalizedDate = Calendar.current.startOfDay(for: draftNextExecutionDate)

        let splitsByIDString = Dictionary(
            uniqueKeysWithValues: draftSplits.map { ($0.key.uuidString, $0.value) }
        )
        let sourceIDString = draftType == .transfer ? draftSourceEnvelopeID?.uuidString : nil

        if let editingItem {
            editingItem.title = draftTitle.isEmpty ? defaultTitle(for: draftType) : draftTitle
            editingItem.type = draftType
            editingItem.nextExecutionDate = normalizedDate
            editingItem.frequency = draftFrequency
            editingItem.totalAmount = draftTotalAmount
            editingItem.splits = splitsByIDString
            editingItem.sourceEnvelopeIDString = sourceIDString
        } else {
            let item = RecurringItem(
                title: draftTitle.isEmpty ? defaultTitle(for: draftType) : draftTitle,
                type: draftType,
                nextExecutionDate: normalizedDate,
                frequency: draftFrequency,
                totalAmount: draftTotalAmount,
                splits: splitsByIDString,
                sourceEnvelopeIDString: sourceIDString
            )
            modelContext.insert(item)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save recurring item: \(error)")
        }
        editingItem = nil
        refresh()
    }

    private func defaultTitle(for type: RecurringItemType) -> String {
        switch type {
        case .paycheck: return "Paycheck"
        case .subscription: return "Subscription"
        case .transfer: return "Transfer"
        }
    }

    func deleteRecurringItem(_ item: RecurringItem) {
        modelContext.delete(item)
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete recurring item: \(error)")
        }
        refresh()
    }
}
