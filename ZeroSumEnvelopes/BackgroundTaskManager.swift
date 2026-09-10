import Foundation
import BackgroundTasks
import SwiftData

/// Registers and runs the background task that applies recurring
/// paychecks/subscriptions/transfers on their scheduled dates, so
/// automation set up in AutomationView keeps running even when the app
/// isn't open.
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

    @MainActor
    private func processDueRecurringItems() async {
        guard let modelContainer else { return }
        let context = ModelContext(modelContainer)

        let now = Date()
        let descriptor = FetchDescriptor<RecurringItem>(
            predicate: #Predicate { $0.nextExecutionDate <= now }
        )

        guard let dueItems = try? context.fetch(descriptor) else { return }

        for item in dueItems {
            apply(item, in: context)
            item.nextExecutionDate = nextDate(after: item.nextExecutionDate, frequency: item.frequency)
        }

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
            // Paychecks land as income split across envelopes; subscriptions
            // land as a single expense against their one destination envelope.
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
            // A single source envelope moving funds into a single
            // destination envelope, possibly in a different account.
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
