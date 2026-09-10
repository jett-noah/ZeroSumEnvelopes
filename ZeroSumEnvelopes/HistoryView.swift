import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let viewModel {
                    if !viewModel.uniqueUsers.isEmpty {
                        Picker("Household Member", selection: Binding(
                            get: { viewModel.selectedUser },
                            set: { viewModel.selectedUser = $0 }
                        )) {
                            Text("All").tag(String?.none)
                            ForEach(viewModel.uniqueUsers, id: \.self) { user in
                                Text(user).tag(Optional(user))
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    TransactionListView(user: viewModel.selectedUser, searchText: searchText)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search transactions")
            .background(Color(.systemGroupedBackground))
            .onAppear {
                if viewModel == nil {
                    viewModel = HistoryViewModel(modelContext: modelContext)
                } else {
                    viewModel?.refresh()
                }
            }
        }
    }
}
