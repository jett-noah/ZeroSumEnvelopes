import SwiftUI
import SwiftData

struct AddTransactionView: View {
    let account: Account

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name) private var allAccounts: [Account]

    @AppStorage("displayName") private var displayName: String = ""

    @State private var viewModel: HomeViewModel?
    @State private var selectedEnvelope: Envelope?
    @State private var destinationEnvelope: Envelope?
    @State private var type: TransactionType = .expense
    @State private var amount: Double = 0
    @State private var notes: String = ""
    @State private var date: Date = .now

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
                        ForEach(account.envelopes.sorted { $0.name < $1.name }) { envelope in
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

                Section("Notes") {
                    TextField("Optional note", text: $notes)
                }
            }
            .navigationTitle(navigationTitleText)
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
            .onAppear {
                if viewModel == nil {
                    viewModel = HomeViewModel(modelContext: modelContext)
                }
            }
        }
    }

    private var navigationTitleText: String {
        switch type {
        case .expense: return "Add Expense"
        case .income: return "Add Income"
        case .transfer: return "Transfer Funds"
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

    private func save() {
        guard let selectedEnvelope, amount > 0 else { return }

        switch type {
        case .transfer:
            guard let destinationEnvelope, destinationEnvelope.id != selectedEnvelope.id else { return }
            viewModel?.transferFunds(
                from: selectedEnvelope,
                to: destinationEnvelope,
                amount: amount,
                userDisplayName: displayName.isEmpty ? "Household" : displayName
            )
        case .income, .expense:
            viewModel?.addTransaction(
                amount: amount,
                type: type,
                envelope: selectedEnvelope,
                notes: notes,
                userDisplayName: displayName.isEmpty ? "Household" : displayName,
                date: date
            )
        }
        dismiss()
    }
}
