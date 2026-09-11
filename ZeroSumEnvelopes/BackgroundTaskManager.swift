import Foundation
import BackgroundTasks
import SwiftData

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
        // A one-hour hint — iOS decides the actual wake time based on the
        // user's real usage patterns, this isn't a guarantee.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)

        BGTaskScheduler.shared.submitTaskRequest(request) { error in
            if let error {
                print("Could not schedule background task: \(error)")
            }
        }
    }

    private func handle(task: BGAppRefreshTask) {
        // Always schedule the next run before doing any work, so a crash
        // or an expired task doesn't strand the whole automation feature.
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
                let sourceEnvelope = envelopesByIDString[sourceIDString]
            else { return }

            for (destinationIDString, amount) in item.splits {
                guard let destinationEnvelope = envelopesByIDString[destinationIDString], amount > 0 else { continue }

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
