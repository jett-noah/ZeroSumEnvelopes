import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var viewModel: HomeViewModel?
    @State private var envelopePendingResolution: Envelope?
    @State private var isAddingAccount = false
    @State private var accountPendingEdit: Account?
    @State private var accountPendingDelete: Account?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let viewModel, !viewModel.overdraftedEnvelopes.isEmpty {
                    overdraftBanner(for: viewModel)
                }

                if accounts.isEmpty {
                    ContentUnavailableView(
                        "No Accounts Yet",
                        systemImage: "building.columns",
                        description: Text("Tap + to add your first account.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(accounts) { account in
                            NavigationLink(value: account) {
                                AccountCardView(account: account)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    accountPendingEdit = account
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    accountPendingDelete = account
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Account.self) { account in
                AccountDetailView(account: account)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingAccount = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = HomeViewModel(modelContext: modelContext)
                } else {
                    viewModel?.refresh()
                }
            }
            .sheet(isPresented: $isAddingAccount) {
                AccountFormView(mode: .create) { name in
                    viewModel?.createAccount(name: name)
                }
            }
            .sheet(item: $accountPendingEdit) { account in
                AccountFormView(mode: .edit(account)) { name in
                    viewModel?.updateAccount(account, name: name)
                }
            }
            .confirmationDialog(
                "Delete \(accountPendingDelete?.name ?? "Account")?",
                isPresented: Binding(
                    get: { accountPendingDelete != nil },
                    set: { isPresented in if !isPresented { accountPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let accountPendingDelete {
                        viewModel?.deleteAccount(accountPendingDelete)
                    }
                    accountPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    accountPendingDelete = nil
                }
            } message: {
                Text("This deletes every envelope and transaction in this account. This can't be undone.")
            }
        }
    }

    private var navigationTitleText: String {
        let total = viewModel?.totalNetWorth ?? accounts.reduce(0) { $0 + $1.totalBalance }
        return "All Accounts: \(total.formatted(.currency(code: "USD")))"
    }

    @ViewBuilder
    private func overdraftBanner(for viewModel: HomeViewModel) -> some View {
        NavigationLink {
            List(viewModel.overdraftedEnvelopes) { envelope in
                Button {
                    envelopePendingResolution = envelope
                } label: {
                    HStack {
                        Text(envelope.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(envelope.currentBalance.formatted(.currency(code: "USD")))
                            .foregroundStyle(.red)
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Overdrawn Envelopes")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $envelopePendingResolution) { envelope in
                ResolveOverdraftView(overdrawnEnvelope: envelope, viewModel: viewModel)
            }
        } label: {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(overdraftMessage(count: viewModel.overdraftedEnvelopes.count))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding()
            .background(Color.red.opacity(0.15))
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func overdraftMessage(count: Int) -> String {
        count == 1 ? "1 envelope needs attention" : "\(count) envelopes need attention"
    }
}

private struct AccountCardView: View {
    let account: Account

    var body: some View {
        HStack {
            Text(account.name)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text(account.totalBalance.formatted(.currency(code: "USD")))
                .font(.title3.bold())
                .foregroundStyle(account.totalBalance < 0 ? .red : .primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct AccountFormView: View {
    enum Mode {
        case create
        case edit(Account)
    }

    let mode: Mode
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(mode: Mode, onSave: @escaping (String) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _name = State(initialValue: "")
        case .edit(let account):
            _name = State(initialValue: account.name)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Account Name (e.g. \"Chase Checking\")", text: $name)
            }
            .navigationTitle(isEditing ? "Edit Account" : "New Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Account.self, Envelope.self, Transaction.self, RecurringItem.self], inMemory: true)
}
