import Foundation
import BackgroundTasks
import SwiftData

/// Registers and runs the background task that applies recurring
/// paychecks/subscriptions/transfers on their scheduled dates. Also called
/// directly from BudgetApp on launch and on returning to the foreground —
/// BGTaskScheduler isn't guaranteed to run promptly (or at all, for an app
/// that isn't backgrounded often), so relying on it alone let recurring
/// items silently fall behind and stay behind.
///
/// Setup required outside this file (not something Claude can do for you
/// from here):
/// 1. Add the "Background Modes" capability -> "Background fetch" /
///    "Background processing" in Xcode's Signing & Capabilities tab.
/// 2. Add a `BGTaskSchedulerPermittedIdentifiers` array to Info.plist
///    containing the string below (`Self.taskIdentifier`).
/// 3. Call `BackgroundTaskManager.shared.register(modelContainer:)` from
///    BudgetApp.init(), before the App's body is ever evaluated.
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    static let taskIdentifier = "com.household.budget.processRecurringItems"
    private static let midnightMigrationKey = "hasMigratedRecurringItemDatesToMidnight"

    private var modelContainer: ModelContainer?

    private init() {}

    func register(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let appRefreshTask = task as? BGAppRefreshTask else { return }
            self?.handle(task: appRefreshTask)
        }
    }

    func scheduleNextRun() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }

    private func handle(task: BGAppRefreshTask) {
        scheduleNextRun()

        let processingTask = Task {
            await processDueRecurringItems()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            processingTask.cancel()
        }
    }

    /// One-time cleanup: floors every existing RecurringItem's
    /// nextExecutionDate to midnight, so items created before automations
    /// were normalized to midnight (see saveDraft() in
    /// AutomationViewModel) match the new behavior too. Runs once ever,
    /// tracked via UserDefaults — safe to call on every launch since it
    /// no-ops immediately after the first successful run.
    @MainActor
    func migrateExistingRecurringItemDatesToMidnightIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.midnightMigrationKey) else { return }
        guard let modelContainer else { return }
        let context = ModelContext(modelContainer)

        let descriptor = FetchDescriptor<RecurringItem>()
        guard let allItems = try? context.fetch(descriptor) else { return }

        let calendar = Calendar.current
        var didChangeAny = false

        for item in allItems {
            let midnight = calendar.startOfDay(for: item.nextExecutionDate)
            if midnight != item.nextExecutionDate {
                item.nextExecutionDate = midnight
                didChangeAny = true
            }
        }

        if didChangeAny {
            do {
                try context.save()
            } catch {
                print("Failed to save midnight migration: \(error)")
            }
        }

        UserDefaults.standard.set(true, forKey: Self.midnightMigrationKey)
    }

    /// Catches up every recurring item that's due, applying it repeatedly
    /// (not just once) until its nextExecutionDate is in the future — so an
    /// item that's been due for months doesn't just advance by a single
    /// interval and stay perpetually behind. Not private: also called
    /// directly from BudgetApp on launch and foreground.
    @MainActor
    func processDueRecurringItems() async {
        guard let modelContainer else { return }
        let context = ModelContext(modelContainer)

        let now = Date()
        let descriptor = FetchDescriptor<RecurringItem>()
        guard let allItems = try? context.fetch(descriptor) else { return }

        var didApplyAny = false

        for item in allItems {
            while item.nextExecutionDate <= now {
                apply(item, in: context)
                let advanced = nextDate(after: item.nextExecutionDate, frequency: item.frequency)
                guard advanced > item.nextExecutionDate else {
                    print("Could not advance nextExecutionDate for recurring item \(item.id) — stopping catch-up.")
                    break
                }
                item.nextExecutionDate = advanced
                didApplyAny = true
            }
        }

        guard didApplyAny else { return }

        do {
            try context.save()
        } catch {
            print("Failed to save processed recurring items: \(error)")
        }
    }

    private func apply(_ item: RecurringItem, in context: ModelContext) {
        let envelopeDescriptor = FetchDescriptor<Envelope>()
        guard let allEnvelopes = try? context.fetch(envelopeDescriptor) else { return }
        let envelopesByIDString = Dictionary(
            uniqueKeysWithValues: allEnvelopes.map { ($0.id.uuidString, $0) }
        )

        switch item.type {
        case .paycheck, .subscription:
            let transactionType: TransactionType = item.type == .paycheck ? .income : .expense

            for (envelopeIDString, amount) in item.splits {
                guard let envelope = envelopesByIDString[envelopeIDString], amount > 0 else { continue }

                let transaction = Transaction(
                    amount: amount,
                    type: transactionType,
                    notes: item.title,
                    userDisplayName: "Automation",
                    envelope: envelope
                )
                context.insert(transaction)
            }

        case .transfer:
            guard
                let sourceIDString = item.sourceEnvelopeIDString,
                let sourceEnvelope = envelopesByIDString[sourceIDString],
                let (destinationIDString, amount) = item.splits.first,
                let destinationEnvelope = envelopesByIDString[destinationIDString],
                amount > 0
            else { return }

            let transaction = Transaction(
                amount: amount,
                type: .transfer,
                notes: item.title,
                userDisplayName: "Automation",
                envelope: sourceEnvelope,
                destinationEnvelope: destinationEnvelope
            )
            context.insert(transaction)
        }
    }

    private func nextDate(after date: Date, frequency: RecurringFrequency) -> Date {
        let calendar = Calendar.current
        switch frequency {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }
}
