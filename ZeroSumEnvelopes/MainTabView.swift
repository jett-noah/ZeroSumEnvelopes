import SwiftUI
import SwiftData
 
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
 
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
 
            AutomationView()
                .tabItem {
                    Label("Automation", systemImage: "arrow.triangle.2.circlepath")
                }
 
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}
 
#Preview {
    MainTabView()
        .modelContainer(for: [Account.self, Envelope.self, Transaction.self, RecurringItem.self], inMemory: true)
}
 
