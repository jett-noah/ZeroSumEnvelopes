import SwiftUI
import SwiftData

/// Presented from HomeView's overdraft banner when the user taps a specific
/// overdrawn envelope. Lets them pick another envelope with available funds
/// and pull money over via HomeViewModel.resolveOverdraft, which records the
/// move as a Transfer transaction.
struct ResolveOverdraftView: View {
    let overdrawnEnvelope: Envelope
    var viewModel: HomeViewModel

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Envelope.name) private var allEnvelopes: [Envelope]

    // Same "displayName" key used throughout the app, so the transfer gets
    // stamped with whoever's using the device.
    @AppStorage("displayName") private var displayName: String = ""

    @State private var sourceEnvelope: Envelope?
    @State private var amount: Double = 0

    private var deficit: Double {
        abs(overdrawnEnvelope.currentBalance)
    }

    private var availableSources: [Envelope] {
        allEnvelopes.filter { $0.id != overdrawnEnvelope.id && $0.currentBalance > 0 }
    }

    private var isValid: Bool {
        guard let sourceEnvelope else { return false }
        return amount > 0 && amount <= sourceEnvelope.currentBalance
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(overdrawnEnvelope.name) {
                    HStack {
                        Text("Currently overdrawn by")
                        Spacer()
                        Text(deficit.formatted(.currency(code: "USD")))
                            .foregroundStyle(.red)
                            .fontWeight(.semibold)
                    }
                }

                Section("Pull Funds From") {
                    if availableSources.isEmpty {
                        Text("No other envelopes have funds available right now.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Source Envelope", selection: $sourceEnvelope) {
                            Text("Select an envelope").tag(Envelope?.none)
                            ForEach(availableSources) { envelope in
                                Text("\(envelope.name) — \(envelope.currentBalance.formatted(.currency(code: "USD")))")
                                    .tag(Optional(envelope))
                            }
                        }
                        .onChange(of: sourceEnvelope) {
                            // Default the amount to whatever clears the
                            // deficit, capped at what the source can cover.
                            guard let sourceEnvelope else { return }
                            amount = min(deficit, sourceEnvelope.currentBalance)
                        }

                        TextField("Amount", value: $amount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)

                        if let sourceEnvelope, amount > sourceEnvelope.currentBalance {
                            Text("Amount exceeds that envelope's balance.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Resolve Overdraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Transfer") { transfer() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func transfer() {
        guard let sourceEnvelope else { return }
        viewModel.resolveOverdraft(
            from: sourceEnvelope,
            to: overdrawnEnvelope,
            amount: amount,
            userDisplayName: displayName.isEmpty ? "Household" : displayName
        )
        dismiss()
    }
}