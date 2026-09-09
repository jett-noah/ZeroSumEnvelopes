import SwiftUI
import SwiftData

/// Presented via long-press ("Edit") on a transaction row in
/// TransactionListView. Edits the transaction in place, scoped to the same
/// account's envelopes as AddTransactionView.
struct EditTransactionView: View {
    let transaction: Transaction

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var type: TransactionType
    @State private var amount: Double
    @State private var notes: String
    @State private var date: Date
    @State private var selectedEnvelope: Envelope?

    private let envelopeOptions: [Envelope]
    private let isTransfer: Bool

    init(transaction: Transaction) {
        self.transaction = transaction
        _type = State(initialValue: transaction.type)
        _amount = State(initialValue: transaction.amount)
        _notes = State(initialValue: transaction.notes)
        _date = State(initialValue: transaction.date)
        _selectedEnvelope = State(initialValue: transaction.envelope)
        envelopeOptions = transaction.envelope?.account?.envelopes.sorted { $0.name < $1.name } ?? []
        isTransfer = transaction.type == .transfer
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .disabled(isTransfer)

                    Picker("Envelope", selection: $selectedEnvelope) {
                        Text("Select an envelope").tag(Envelope?.none)
                        ForEach(envelopeOptions) { envelope in
                            Text(envelope.name).tag(Optional(envelope))
                        }
                    }

                    TextField("Amount", value: $amount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Notes") {
                    TextField("Optional note", text: $notes)
                }
            }
            .navigationTitle("Edit \(type == .income ? "Income" : type == .expense ? "Expense" : "Transfer")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        selectedEnvelope != nil && amount > 0
    }

    private func save() {
        guard let selectedEnvelope, amount > 0 else { return }
        transaction.type = type
        transaction.amount = amount
        transaction.notes = notes
        transaction.date = date
        transaction.envelope = selectedEnvelope

        do {
            try modelContext.save()
        } catch {
            print("Failed to save transaction edit: \(error)")
        }
        dismiss()
    }
}