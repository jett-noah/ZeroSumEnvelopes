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
    var chartData: [(category: String, amount: Double)] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }
    
    func refresh() {
        let descriptor = FetchDescriptor<Transaction>()
        let allTransactions = (try? modelContext.fetch(descriptor)) ?? []
        
        // Extract unique household members who have made transactions
        let users = Set(allTransactions.map { $0.userDisplayName })
        uniqueUsers = Array(users).sorted()
        
        // Filter transactions based on the selected picker segment
        let filtered = allTransactions.filter { 
            selectedUser == nil || $0.userDisplayName == selectedUser
        }
        
        // Only chart expenses (ignoring income/transfers)
        let expenses = filtered.filter { $0.type == .expense }
        
        // Group expenses by their envelope name, then sum the amounts
        let grouped = Dictionary(grouping: expenses) { $0.envelope?.name ?? "Uncategorized" }
        chartData = grouped.map { (key, value) in
            (category: key, amount: value.reduce(0) { $0 + $1.amount })
        }.sorted { $0.amount > $1.amount }
    }
}