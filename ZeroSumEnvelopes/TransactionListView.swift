import SwiftUI
import SwiftData

/// Reusable across the app: EnvelopeDetailView passes an `envelope` filter,
/// HistoryView passes a `user` filter (or nothing, for "all") plus a live
/// `searchText`. envelope/user narrow the underlying @Query; searchText is
/// applied client-side afterward.
struct TransactionListView: View {
    @Query private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext

    var searchText: String

    @State private var transactionPendingEdit: Transaction?

    init(envelope: Envelope? = nil, user: String? = nil, searchText: String = "") {
        self.searchText = searchText
        let envelopeID = envelope?.id

        switch (envelopeID, user) {
        case let (envelopeID?, user?):
            _transactions = Query(
                filter: #Predicate<Transaction> { transaction in
                    transaction.envelope?.id == envelopeID && transaction.userDisplayName == user
                },
                sort: [SortDescriptor(\.date, order: .reverse)]
            )
        case let (envelopeID?, nil):
            _transactions = Query(
                filter: #Predicate<Transaction> { transaction in
                    transaction.envelope?.id == envelopeID
                },
                sort: [SortDescriptor(\.date, order: .reverse)]
            )
        case let (nil, user?):
            _transactions = Query(
                filter: #Predicate<Transaction> { transaction in
                    transaction.userDisplayName == user
                },
                sort: [SortDescriptor(\.date, order: .reverse)]
            )
        case (nil, nil):
            _transactions = Query(sort: [SortDescriptor(\.date, order: .reverse)])
        }
    }

    private var searchFilteredTransactions: [Transaction] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return transactions }
        return transactions.filter { transaction in
            transaction.notes.lowercased().contains(query)
                || (transaction.envelope?.name.lowercased().contains(query) ?? false)
                || transaction.userDisplayName.lowercased().contains(query)
        }
    }

    private var groupedByMonth: [(month: Date, days: [(day: Date, transactions: [Transaction])])] {
        let calendar = Calendar.current

        let byMonth = Dictionary(grouping: searchFilteredTransactions) { transaction in
            calendar.dateInterval(of: .month, for: transaction.date)?.start ?? transaction.date
        }

        return byMonth
            .sorted { $0.key > $1.key }
            .map { month, monthTransactions in
                let byDay = Dictionary(grouping: monthTransactions) { transaction in
                    calendar.startOfDay(for: transaction.date)
                }
                let days = byDay
                    .sorted { $0.key > $1.key }
                    .map { day, dayTransactions in
                        (day: day, transactions: dayTransactions.sorted { $0.date > $1.date })
                    }
                return (month: month, days: days)
            }
    }

    var body: some View {
        List {
            if searchFilteredTransactions.isEmpty {
                ContentUnavailableView(
                    transactions.isEmpty ? "No Transactions" : "No Results",
                    systemImage: transactions.isEmpty ? "tray" : "magnifyingglass",
                    description: Text(
                        transactions.isEmpty
                            ? "Transactions will show up here once they're added."
                            : "No transactions match your search."
                    )
                )
            } else {
                ForEach(groupedByMonth, id: \.month) { monthGroup in
                    DisclosureGroup(monthGroup.month.formatted(.dateTime.month(.wide).year())) {
                        ForEach(monthGroup.days, id: \.day) { dayGroup in
                            Section(dayGroup.day.formatted(.dateTime.weekday(.wide).month().day())) {
                                ForEach(dayGroup.transactions) { transaction in
                                    TransactionRow(transaction: transaction)
                                        .contextMenu {
                                            Button {
                                                transactionPendingEdit = transaction
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            Button(role: .destructive) {
                                                delete(transaction)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $transactionPendingEdit) { transaction in
            EditTransactionView(transaction: transaction)
        }
    }

    private func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete transaction: \(error)")
        }
    }
}

private struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.notes.isEmpty ? transaction.type.rawValue.capitalized : transaction.notes)
                Text(transaction.userDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(signedAmountText)
                .foregroundStyle(transaction.type == .income ? .green : .primary)
        }
    }

    private var signedAmountText: String {
        switch transaction.type {
        case .income:
            return "+\(transaction.amount.formatted(.currency(code: "USD")))"
        case .expense, .transfer:
            return "-\(transaction.amount.formatted(.currency(code: "USD")))"
        }
    }
}
