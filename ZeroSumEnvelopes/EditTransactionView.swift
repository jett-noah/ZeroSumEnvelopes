import SwiftUI
import SwiftData

struct EditTransactionView: View {
    let transaction: Transaction

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name) private var allAccounts: [Account]

    @AppStorage("displayName") private var displayName: String = ""

    @State private var type: TransactionType
    @State private var amount: Double
    @State private var notes: String
    @State private var tagsText: String
    @State private var date: Date
    @State private var selectedEnvelope: Envelope?
    @State private var destinationEnvelope: Envelope?
    @State private var isShowingOverdraftPrompt = false

    private let envelopeOptions: [Envelope]

    init(transaction: Transaction) {
        self.transaction = transaction
        _type = State(initialValue: transaction.type)
        _amount = State(initialValue: transaction.amount)
        _notes = State(initialValue: transaction.notes)
        _tagsText = State(initialValue: transaction.tags.joined(separator: ", "))
        _date = State(initialValue: transaction.date)
        _selectedEnvelope = State(initialValue: transaction.envelope)
        _destinationEnvelope = State(initialValue: transaction.destinationEnvelope)
        envelopeOptions = transaction.envelope?.account?.envelopes.sorted { $0.name < $1.name } ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                        Text("Transfer").tag(TransactionType.transfer)
                    }
                    .pickerStyle(.segmented)

                    Picker(type == .transfer ? "From Envelope" : "Envelope", selection: $selectedEnvelope) {
                        Text("Select an envelope").tag(Envelope?.none)
                        ForEach(envelopeOptions) { envelope in
                            Text(envelope.name).tag(Optional(envelope))
                        }
                    }

                    if type == .transfer {
                        Picker("To Envelope", selection: $destinationEnvelope) {
                            Text("Select an envelope").tag(Envelope?.none)
                            ForEach(allAccounts) { destinationAccount in
                                let envelopes = destinationAccount.envelopes
                                    .filter { $0.id != selectedEnvelope?.id }
                                    .sorted { $0.name < $1.name }
                                if !envelopes.isEmpty {
                                    Section(destinationAccount.name) {
                                        ForEach(envelopes) { envelope in
                                            Text(envelope.name).tag(Optional(envelope))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    TextField("Amount", value: $amount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Notes & Tags") {
                    TextField("Optional note", text: $notes)
                    TagsInputField(tagsText: $tagsText)
                }
            }
            .navigationTitle("Edit \(titleSuffix)")
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
            .sheet(isPresented: $isShowingOverdraftPrompt) {
                if let selectedEnvelope {
                    let base = projectedBalance(for: selectedEnvelope)
                    OverdraftCoveragePrompt(
                        envelope: selectedEnvelope,
                        expenseAmount: amount,
                        shortfall: amount - base,
                        onCoverFromEnvelope: { coverageEnvelope in
                            applyCoverage(from: coverageEnvelope, to: selectedEnvelope, amount: amount - base)
                            commit(envelope: selectedEnvelope)
                        },
                        onProceedAnyway: {
                            commit(envelope: selectedEnvelope)
                        }
                    )
                }
            }
        }
    }

    private var titleSuffix: String {
        switch type {
        case .income: return "Income"
        case .expense: return "Expense"
        case .transfer: return "Transfer"
        }
    }

    private var isValid: Bool {
        guard amount > 0, let selectedEnvelope else { return false }
        if type == .transfer {
            guard let destinationEnvelope else { return false }
            return destinationEnvelope.id != selectedEnvelope.id
        }
        return true
    }

    private func projectedBalance(for envelope: Envelope) -> Double {
        var reversal: Double = 0
        if transaction.envelope?.id == envelope.id {
            switch transaction.type {
            case .income:
                reversal = -transaction.amount
            case .expense, .transfer:
                reversal = transaction.amount
            }
        } else if transaction.destinationEnvelope?.id == envelope.id {
            reversal = -transaction.amount
        }
        return envelope.currentBalance + reversal
    }

    private func save() {
        guard let selectedEnvelope, amount > 0 else { return }

        if type == .expense {
            let base = projectedBalance(for: selectedEnvelope)
            if amount > base {
                isShowingOverdraftPrompt = true
                return
            }
        }

        commit(envelope: selectedEnvelope)
    }

    private func applyCoverage(from source: Envelope, to destination: Envelope, amount: Double) {
        guard amount > 0, source.id != destination.id else { return }
        let transfer = Transaction(
            amount: amount,
            type: .transfer,
            notes: "Overdraft coverage",
            userDisplayName: displayName.isEmpty ? "Household" : displayName,
            envelope: source,
            destinationEnvelope: destination
        )
        modelContext.insert(transfer)
    }

    private func commit(envelope: Envelope) {
        if type == .transfer {
            guard let destinationEnvelope, destinationEnvelope.id != envelope.id else { return }
            transaction.destinationEnvelope = destinationEnvelope
        } else {
            transaction.destinationEnvelope = nil
        }

        transaction.type = type
        transaction.amount = amount
        transaction.notes = notes
        transaction.tags = TagsInputField.parse(tagsText)
        transaction.date = date
        transaction.envelope = envelope

        do {
            try modelContext.save()
        } catch {
            print("Failed to save transaction edit: \(error)")
        }
        dismiss()
    }
}
