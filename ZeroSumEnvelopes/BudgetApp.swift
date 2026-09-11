import SwiftUI
import SwiftData

@main
struct BudgetApp: App {
    let modelContainer: ModelContainer

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let schema = Schema([
            Account.self,
            Envelope.self,
            Transaction.self,
            RecurringItem.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        BackgroundTaskManager.shared.register(modelContainer: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    // One-time cleanup for pre-existing items, then the
                    // regular catch-up check. .task lives on the content
                    // view, not the Scene, since Scene has no .task
                    // modifier.
                    await BackgroundTaskManager.shared.migrateExistingRecurringItemDatesToMidnightIfNeeded()
                    await BackgroundTaskManager.shared.processDueRecurringItems()
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await BackgroundTaskManager.shared.processDueRecurringItems()
                }
            case .background:
                BackgroundTaskManager.shared.scheduleNextRun()
            default:
                break
            }
        }
    }
}
