import Foundation
import SwiftData
import Observation

@Observable
final class HomeViewModel {
    private var modelContext: ModelContext

    var totalNetWorth: Double = 0
    var overdraftedEnvelopes: [Envelope] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    func refresh() {
        calculateTotalNetWorth()
        checkOverdrafts()
    }

    func calculateTotalNetWorth() {
        let descriptor = FetchDescriptor<Account>()
        let accounts = (try? modelContext.fetch(descriptor)) ?? []
        totalNetWorth = accounts.reduce(0) { $0 + $1.totalBalance }
    }

    func checkOverdrafts() {
        let descriptor = FetchDescriptor<Envelope>()
        let envelopes = (try? modelContext.fetch(descriptor)) ?? []
        overdraftedEnvelopes = envelopes.filter { $0.isOverdrafted }
    }

    // MARK: - Account CRUD

    func createAccount(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Account(name: trimmed))
        save()
        refresh()
    }

    func updateAccount(_ account: Account, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        account.name = trimmed
        save()
    }

    func deleteAccount(_ account: Account) {
        modelContext.delete(account)
        save()
        refresh()
    }

    // MARK: - Transfers

    func transferFunds(
        from sourceEnvelope: Envelope,
        to destinationEnvelope: Envelope,
        amount: Double,
        userDisplayName: String
    ) {
        guard amount > 0, sourceEnvelope.id != destinationEnvelope.id else { return }

        let transferTransaction = Transaction(
            amount: amount,
            type: .transfer,
            userDisplayName: userDisplayName,
            envelope: sourceEnvelope,
            destinationEnvelope: destinationEnvelope
        )
        modelContext.insert(transferTransaction)
        save()
        refresh()
    }

    /// Thin wrapper kept for the overdraft-resolution flow specifically —
    /// same underlying transfer as transferFunds(from:to:amount:userDisplayName:).
    func resolveOverdraft(
        from sourceEnvelope: Envelope,
        to overdrawnEnvelope: Envelope,
        amount: Double,
        userDisplayName: String
    ) {
        transferFunds(
            from: sourceEnvelope,
            to: overdrawnEnvelope,
            amount: amount,
            userDisplayName: userDisplayName
        )
    }

    func addTransaction(
        amount: Double,
        type: TransactionType,
        envelope: Envelope,
        notes: String = "",
        tags: [String] = [],
        userDisplayName: String,
        date: Date = .now
    ) {
        guard amount > 0 else { return }
        guard type != .transfer else {
            // Transfers need a destination envelope — use transferFunds or
            // resolveOverdraft instead of this entry point.
            return
        }

        let transaction = Transaction(
            amount: amount,
            date: date,
            type: type,
            notes: notes,
            tags: tags,
            userDisplayName: userDisplayName,
            envelope: envelope
        )
        modelContext.insert(transaction)
        save()
        refresh()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("HomeViewModel save failed: \(error)")
        }
    }
}
