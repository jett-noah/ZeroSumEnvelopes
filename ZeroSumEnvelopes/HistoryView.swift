import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "History",
                systemImage: "clock.arrow.circlepath",
                description: Text("Transaction history and charts arrive in a later file set.")
            )
            .navigationTitle("History")
        }
    }
}

#Preview {
    HistoryView()
}
