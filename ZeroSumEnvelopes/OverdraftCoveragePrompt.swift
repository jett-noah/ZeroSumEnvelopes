import SwiftUI
import SwiftData

struct OverdraftCoveragePrompt: View {
    let envelope: Envelope
    let expenseAmount: Double
    let shortfall: Double

    var onCoverFromEnvelope: (Envelope) -> Void
    var onProceedAnyway: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var selectedEnvelope: Envelope?

    private var availableSources: [Envelope] {
        accounts
            .flatMap { $0.envelopes }
            .filter { $0.id != envelope.id && $0.currentBalance > 0 }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This \(expenseAmount.formatted(.currency(code: "USD"))) expense would overdraw \(envelope.name) by \(shortfall.formatted(.currency(code: "USD"))).")
                }

                Section("Cover the Shortfall") {
                    if availableSources.isEmpty {
                        Text("No other envelopes have funds available right now.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("From Envelope", selection: $selectedEnvelope) {
                            Text("Select an envelope").tag(Envelope?.none)
                            ForEach(availableSources) { source in
                                Text("\(source.name) — \(source.currentBalance.formatted(.currency(code: "USD")))")
                                    .tag(Optional(source))
                            }
                        }

                        Button("Cover \(shortfall.formatted(.currency(code: "USD"))) From This Envelope") {
                            guard let selectedEnvelope else { return }
                            onCoverFromEnvelope(selectedEnvelope)
                            dismiss()
                        }
                        .disabled(selectedEnvelope == nil)
                    }
                }

                Section {
                    Button("Save Anyway (Allow Overdraft)", role: .destructive) {
                        onProceedAnyway()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Overdraft Warning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
