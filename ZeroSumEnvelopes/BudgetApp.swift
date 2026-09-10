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

        // .automatic lets SwiftData mirror the local store to each user's
        // private CloudKit database, then CloudSharingManager upgrades a
        // specific record's zone to a shared one so household members can
        // collaborate on it.
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

        // Registering the background task's handler must happen before the
        // app finishes launching — see BackgroundTaskManager.swift's header
        // comment for the Info.plist / capability setup this depends on.
        BackgroundTaskManager.shared.register(modelContainer: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundTaskManager.shared.scheduleNextRun()
            }
        }
    }
}
