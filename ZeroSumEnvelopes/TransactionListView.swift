import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Query private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext

    var searchText: String

    private let contextEnvelopeID: UUID?

    @State private var transactionPendingEdit: Transaction?
    @State private var transactionPendingDelete: Transaction?

    init(envelope: Envelope? = nil, user: String? = nil, searchText: String = "") {
        self.searchText = searchText
        let envelopeID = envelope?.id
        self.contextEnvelopeID = envelopeID

        switch (envelopeID, user) {
        case let (envelopeID?, user?):
            _transactions = Query(
                filter: #Predicate<Transaction> { transaction in
                    (transaction.envelope?.id == envelopeID || transaction.destinationEnvelope?.id == envelopeID)
                        && transaction.userDisplayName == user
                },
                sort: [SortDescriptor(\.date, order: .reverse)]
            )
        case let (envelopeID?, nil):
            _transactions = Query(
                filter: #Predicate<Transaction> { transaction in
                    transaction.envelope?.id == envelopeID || transaction.destinationEnvelope?.id == envelopeID
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
                || (transaction.destinationEnvelope?.name.lowercased().contains(query) ?? false)
                || transaction.userDisplayName.lowercased().contains(query)
                || transaction.tags.contains { $0.lowercased().contains(query) }
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
                                    TransactionRow(transaction: transaction, contextEnvelopeID: contextEnvelopeID)
                                        .contextMenu {
                                            Button {
                                                transactionPendingEdit = transaction
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            Button(role: .destructive) {
                                                transactionPendingDelete = transaction
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
        .refreshable {
            await BackgroundTaskManager.shared.processDueRecurringItems()
        }
        .sheet(item: $transactionPendingEdit) { transaction in
            EditTransactionView(transaction: transaction)
        }
        .confirmationDialog(
            "Delete this transaction?",
            isPresented: Binding(
                get: { transactionPendingDelete != nil },
                set: { isPresented in if !isPresented { transactionPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let transactionPendingDelete {
                    delete(transactionPendingDelete)
                }
                transactionPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                transactionPendingDelete = nil
            }
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
    let contextEnvelopeID: UUID?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryLabel)
                if !transaction.tags.isEmpty {
                    tagRow
                }
                Text(transaction.userDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(signedAmountText)
                .foregroundStyle(amountColor)
        }
    }

    private var isIncomingHere: Bool {
        transaction.type == .transfer && contextEnvelopeID != nil && contextEnvelopeID == transaction.destinationEnvelope?.id
    }

    private var isOutgoingHere: Bool {
        transaction.type == .transfer && contextEnvelopeID != nil && contextEnvelopeID == transaction.envelope?.id
    }

    private var primaryLabel: String {
        if transaction.type == .transfer {
            if isIncomingHere, let sourceName = transaction.envelope?.name {
                return notesOrDefault("Transfer from \(sourceName)")
            }
            if isOutgoingHere, let destinationName = transaction.destinationEnvelope?.name {
                return notesOrDefault("Transfer to \(destinationName)")
            }
            let sourceName = transaction.envelope?.name ?? "?"
            let destinationName = transaction.destinationEnvelope?.name ?? "?"
            return notesOrDefault("Transfer: \(sourceName) → \(destinationName)")
        }
        return notesOrDefault(transaction.type.rawValue.capitalized)
    }

    private func notesOrDefault(_ fallback: String) -> String {
        transaction.notes.isEmpty ? fallback : transaction.notes
    }

    private var signedAmountText: String {
        if transaction.type == .transfer {
            if isIncomingHere {
                return "+\(transaction.amount.formatted(.currency(code: "USD")))"
            }
            if isOutgoingHere {
                return "-\(transaction.amount.formatted(.currency(code: "USD")))"
            }
            return transaction.amount.formatted(.currency(code: "USD"))
        }
        switch transaction.type {
        case .income:
            return "+\(transaction.amount.formatted(.currency(code: "USD")))"
        case .expense:
            return "-\(transaction.amount.formatted(.currency(code: "USD")))"
        case .transfer:
            return transaction.amount.formatted(.currency(code: "USD"))
        }
    }

    private var amountColor: Color {
        if transaction.type == .income || isIncomingHere {
            return .green
        }
        return .primary
    }

    @ViewBuilder
    private var tagRow: some View {
        HStack(spacing: 4) {
            ForEach(transaction.tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
    }
}
