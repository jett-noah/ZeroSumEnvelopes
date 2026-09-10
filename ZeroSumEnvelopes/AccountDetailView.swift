import SwiftUI
import SwiftData

struct AccountDetailView: View {
    @Bindable var account: Account
    @Environment(\.modelContext) private var modelContext

    @Query private var envelopes: [Envelope]

    @State private var isAddingTransaction = false
    @State private var isAddingEnvelope = false
    @State private var envelopePendingEdit: Envelope?

    init(account: Account) {
        self.account = account

        let accountID = account.id
        _envelopes = Query(
            filter: #Predicate<Envelope> { $0.account?.id == accountID },
            sort: \Envelope.name
        )
    }

    private var existingGroups: [String] {
        Set(envelopes.compactMap { $0.groupName }).sorted()
    }

    /// Ungrouped envelopes sort last; everything else is alphabetical by
    /// group name so a newly-added group doesn't jump around the list.
    private var groupedEnvelopes: [(group: String, envelopes: [Envelope])] {
        let grouped = Dictionary(grouping: envelopes) { $0.groupName ?? "Ungrouped" }
        return grouped
            .sorted { lhs, rhs in
                if lhs.key == "Ungrouped" { return false }
                if rhs.key == "Ungrouped" { return true }
                return lhs.key < rhs.key
            }
            .map { (group: $0.key, envelopes: $0.value.sorted { $0.name < $1.name }) }
    }

    var body: some View {
        List {
            // Skip section headers until the user actually groups
            // something — an all-"Ungrouped" list with one header looks odd.
            if groupedEnvelopes.count <= 1 {
                ForEach(envelopes) { envelope in
                    envelopeRow(for: envelope)
                }
            } else {
                ForEach(groupedEnvelopes, id: \.group) { groupData in
                    Section(groupData.group) {
                        ForEach(groupData.envelopes) { envelope in
                            envelopeRow(for: envelope)
                        }
                    }
                }
            }
        }
        .navigationTitle("\(account.name) Total: \(account.totalBalance.formatted(.currency(code: "USD")))")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Envelope.self) { envelope in
            EnvelopeDetailView(envelope: envelope)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Transaction") {
                        isAddingTransaction = true
                    }
                    .disabled(envelopes.isEmpty)

                    Button("New Envelope") {
                        isAddingEnvelope = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingTransaction) {
            AddTransactionView(account: account)
        }
        .sheet(isPresented: $isAddingEnvelope) {
            EnvelopeFormView(mode: .create, existingGroups: existingGroups) { name, groupName, targetAmount, targetDate in
                let envelope = Envelope(
                    name: name,
                    groupName: groupName,
                    targetAmount: targetAmount,
                    targetDate: targetDate
                )
                envelope.account = account
                modelContext.insert(envelope)
                try? modelContext.save()
            }
        }
        .sheet(item: $envelopePendingEdit) { envelope in
            EnvelopeFormView(mode: .edit(envelope), existingGroups: existingGroups) { name, groupName, targetAmount, targetDate in
                envelope.name = name
                envelope.groupName = groupName
                envelope.targetAmount = targetAmount
                envelope.targetDate = targetDate
                try? modelContext.save()
            }
        }
    }

    @ViewBuilder
    private func envelopeRow(for envelope: Envelope) -> some View {
        NavigationLink(value: envelope) {
            EnvelopeRow(envelope: envelope)
        }
        .contextMenu {
            Button {
                envelopePendingEdit = envelope
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                modelContext.delete(envelope)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct EnvelopeRow: View {
    let envelope: Envelope

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(envelope.name)
                if envelope.isOverdrafted {
                    Text("Overdrawn")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            Text(envelope.currentBalance.formatted(.currency(code: "USD")))
                .foregroundStyle(envelope.isOverdrafted ? .red : .primary)
        }
    }
}
