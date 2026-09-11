import SwiftUI

struct EnvelopeDetailView: View {
    let envelope: Envelope

    @State private var isAddingTransaction = false

    var body: some View {
        VStack(spacing: 0) {
            balanceHeader
            TransactionListView(envelope: envelope)
        }
        .navigationTitle(envelope.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if envelope.account != nil {
                    Button {
                        isAddingTransaction = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingTransaction) {
            if let account = envelope.account {
                AddTransactionView(account: account, preselectedEnvelope: envelope)
            }
        }
    }

    private var balanceHeader: some View {
        VStack(spacing: 4) {
            Text("Remaining Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(envelope.currentBalance.formatted(.currency(code: "USD")))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(envelope.isOverdrafted ? .red : .primary)

            if let targetAmount = envelope.targetAmount {
                targetProgress(targetAmount: targetAmount)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private func targetProgress(targetAmount: Double) -> some View {
        let progress = targetAmount > 0
            ? min(max(envelope.currentBalance / targetAmount, 0), 1)
            : 0

        VStack(spacing: 4) {
            ProgressView(value: progress)
                .tint(.accentColor)
            HStack {
                Text("Goal: \(targetAmount.formatted(.currency(code: "USD")))")
                if let targetDate = envelope.targetDate {
                    Spacer()
                    Text("by \(targetDate.formatted(.dateTime.month().day().year()))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
        .padding(.top, 4)
    }
}
