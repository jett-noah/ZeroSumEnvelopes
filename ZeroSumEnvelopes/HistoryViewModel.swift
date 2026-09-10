import Foundation
import SwiftData
import Observation

@Observable
final class HistoryViewModel {
    private var modelContext: ModelContext

    // The currently selected user for the filter picker. nil = "All"
    var selectedUser: String? = nil {
        didSet { refresh() }
    }

    var uniqueUsers: [String] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    func refresh() {
        let descriptor = FetchDescriptor<Transaction>()
        let allTransactions = (try? modelContext.fetch(descriptor)) ?? []

        let users = Set(allTransactions.map { $0.userDisplayName })
        uniqueUsers = Array(users).sorted()
    }
}
