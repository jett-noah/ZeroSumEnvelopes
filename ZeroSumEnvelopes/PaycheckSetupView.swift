import SwiftUI
import SwiftData

struct PaycheckSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    @Bindable var viewModel: AutomationViewModel
    var item: RecurringItem? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                unallocatedBanner

                Form {
                    Section("Paycheck") {
                        TextField("Title (e.g. \"Noah's Paycheck\")", text: $viewModel.draftTitle)

                        TextField(
                            "Total Amount",
                            value: $viewModel.draftTotalAmount,
                            format: .currency(code: "USD")
                        )
                        .keyboardType(.decimalPad)
                        .onChange(of: viewModel.draftTotalAmount) {
                            viewModel.calculateUnallocatedFunds()
                        }

                        DatePicker(
                            "Next Payday",
                            selection: $viewModel.draftNextExecutionDate,
                            displayedComponents: .date
                        )

                        Picker("Frequency", selection: $viewModel.draftFrequency) {
                            Text("Weekly").tag(RecurringFrequency.weekly)
                            Text("Bi-weekly").tag(RecurringFrequency.biweekly)
                            Text("Monthly").tag(RecurringFrequency.monthly)
                        }
                    }

                    ForEach(accounts) { account in
                        let envelopes = account.envelopes.sorted { $0.name < $1.name }
                        if !envelopes.isEmpty {
                            Section(account.name) {
                                ForEach(envelopes) { envelope in
                                    envelopeSplitRow(for: envelope)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(item == nil ? "New Paycheck" : "Edit Paycheck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveDraft()
                        dismiss()
                    }
                    .disabled(!viewModel.isValidToSave)
                }
            }
            .onAppear {
                if let item {
                    viewModel.loadDraft(from: item)
                } else {
                    viewModel.resetDraft(type: .paycheck)
                }
            }
        }
    }

    private var unallocatedBanner: some View {
        HStack {
            Text("Unallocated")
                .font(.subheadline)
            Spacer()
            Text(viewModel.unallocatedAmount.formatted(.currency(code: "USD")))
                .font(.subheadline.weight(.semibold))
        }
        .padding()
        .background(bannerColor.opacity(0.15))
        .foregroundStyle(bannerColor)
    }

    private var bannerColor: Color {
        abs(viewModel.unallocatedAmount) < 0.005 ? .green : .orange
    }

    @ViewBuilder
    private func envelopeSplitRow(for envelope: Envelope) -> some View {
        HStack {
            Text(envelope.name)
            Spacer()
            TextField(
                "Amount",
                value: Binding(
                    get: { viewModel.draftSplits[envelope.id] ?? 0 },
                    set: { viewModel.setSplit($0, for: envelope) }
                ),
                format: .currency(code: "USD")
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 120)

            if abs(viewModel.unallocatedAmount) >= 0.005 {
                Button {
                    viewModel.quickSweep(to: envelope)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
