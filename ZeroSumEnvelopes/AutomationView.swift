import SwiftUI
import SwiftData

struct AutomationView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: AutomationViewModel?
    @State private var isAddingPaycheck = false
    @State private var isAddingSubscription = false
    @State private var isAddingTransfer = false
    @State private var itemPendingEdit: RecurringItem?
    @State private var itemPendingDelete: RecurringItem?

    var body: some View {
        NavigationStack {
            List {
                Section("Upcoming Paychecks") {
                    let paychecks = viewModel?.recurringItems.filter { $0.type == .paycheck } ?? []
                    if paychecks.isEmpty {
                        Text("No paychecks scheduled yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(paychecks) { item in
                            RecurringItemRow(item: item)
                                .contextMenu {
                                    Button {
                                        itemPendingEdit = item
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        itemPendingDelete = item
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { offsets in delete(paychecks, at: offsets) }
                    }
                }

                Section("Active Subscriptions") {
                    let subscriptions = viewModel?.recurringItems.filter { $0.type == .subscription } ?? []
                    if subscriptions.isEmpty {
                        Text("No subscriptions yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(subscriptions) { item in
                            RecurringItemRow(item: item)
                                .contextMenu {
                                    Button {
                                        itemPendingEdit = item
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        itemPendingDelete = item
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { offsets in delete(subscriptions, at: offsets) }
                    }
                }

                Section("Scheduled Transfers") {
                    let transfers = viewModel?.recurringItems.filter { $0.type == .transfer } ?? []
                    if transfers.isEmpty {
                        Text("No scheduled transfers yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(transfers) { item in
                            RecurringItemRow(item: item)
                                .contextMenu {
                                    Button {
                                        itemPendingEdit = item
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        itemPendingDelete = item
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { offsets in delete(transfers, at: offsets) }
                    }
                }
            }
            .refreshable {
                await BackgroundTaskManager.shared.processDueRecurringItems()
                viewModel?.refresh()
            }
            .navigationTitle("Automation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New Paycheck") { isAddingPaycheck = true }
                        Button("New Subscription") { isAddingSubscription = true }
                        Button("New Transfer") { isAddingTransfer = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = AutomationViewModel(modelContext: modelContext)
                } else {
                    viewModel?.refresh()
                }
            }
            .sheet(isPresented: $isAddingPaycheck) {
                if let viewModel {
                    PaycheckSetupView(viewModel: viewModel)
                }
            }
            .sheet(isPresented: $isAddingSubscription) {
                if let viewModel {
                    SubscriptionSetupView(viewModel: viewModel)
                }
            }
            .sheet(isPresented: $isAddingTransfer) {
                if let viewModel {
                    TransferSetupView(viewModel: viewModel)
                }
            }
            .sheet(item: $itemPendingEdit) { item in
                if let viewModel {
                    switch item.type {
                    case .paycheck:
                        PaycheckSetupView(viewModel: viewModel, item: item)
                    case .subscription:
                        SubscriptionSetupView(viewModel: viewModel, item: item)
                    case .transfer:
                        TransferSetupView(viewModel: viewModel, item: item)
                    }
                }
            }
            .confirmationDialog(
                "Delete \(itemPendingDelete?.title ?? "this item")?",
                isPresented: Binding(
                    get: { itemPendingDelete != nil },
                    set: { isPresented in if !isPresented { itemPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let itemPendingDelete {
                        viewModel?.deleteRecurringItem(itemPendingDelete)
                    }
                    itemPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    itemPendingDelete = nil
                }
            } message: {
                Text("This stops the automation. It won't affect transactions it already created.")
            }
        }
    }

    private func delete(_ items: [RecurringItem], at offsets: IndexSet) {
        for index in offsets {
            viewModel?.deleteRecurringItem(items[index])
        }
    }
}

private struct RecurringItemRow: View {
    let item: RecurringItem

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.title)
                Text(item.frequency.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(item.totalAmount.formatted(.currency(code: "USD")))
                Text(item.nextExecutionDate.formatted(.dateTime.month().day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SubscriptionSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    var viewModel: AutomationViewModel
    var item: RecurringItem? = nil

    @State private var title = ""
    @State private var amount: Double = 0
    @State private var frequency: RecurringFrequency = .monthly
    @State private var nextExecutionDate: Date = .now
    @State private var selectedEnvelope: Envelope?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title (e.g. \"Netflix\")", text: $title)
                TextField("Amount", value: $amount, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                Picker("Frequency", selection: $frequency) {
                    Text("Weekly").tag(RecurringFrequency.weekly)
                    Text("Bi-weekly").tag(RecurringFrequency.biweekly)
                    Text("Monthly").tag(RecurringFrequency.monthly)
                }
                DatePicker("Next Charge", selection: $nextExecutionDate, displayedComponents: .date)

                Picker("Envelope", selection: $selectedEnvelope) {
                    Text("Select an envelope").tag(Envelope?.none)
                    ForEach(accounts) { account in
                        ForEach(account.envelopes.sorted { $0.name < $1.name }) { envelope in
                            Text(envelope.name).tag(Optional(envelope))
                        }
                    }
                }
            }
            .navigationTitle(item == nil ? "New Subscription" : "Edit Subscription")
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
                guard let item else { return }
                title = item.title
                amount = item.totalAmount
                frequency = item.frequency
                nextExecutionDate = item.nextExecutionDate
                if let (idString, _) = item.splits.first, let uuid = UUID(uuidString: idString) {
                    selectedEnvelope = accounts
                        .flatMap { $0.envelopes }
                        .first { $0.id == uuid }
                }
            }
        }
    }

    private var isValid: Bool {
        !title.isEmpty && amount > 0 && selectedEnvelope != nil
    }

    private func save() {
        guard let envelope = selectedEnvelope, amount > 0 else { return }

        if let item {
            viewModel.loadDraft(from: item)
        } else {
            viewModel.resetDraft(type: .subscription)
        }
        viewModel.draftTitle = title
        viewModel.draftTotalAmount = amount
        viewModel.draftFrequency = frequency
        viewModel.draftNextExecutionDate = nextExecutionDate
        viewModel.draftSplits = [:]
        viewModel.setSplit(amount, for: envelope)
        viewModel.saveDraft()
        dismiss()
    }
}


private struct TransferSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    @Bindable var viewModel: AutomationViewModel
    var item: RecurringItem? = nil

    @State private var sourceEnvelope: Envelope?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                unallocatedBanner

                Form {
                    Section("Transfer") {
                        TextField("Title (e.g. \"Vacation Fund\")", text: $viewModel.draftTitle)

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
                            "Next Transfer",
                            selection: $viewModel.draftNextExecutionDate,
                            displayedComponents: .date
                        )

                        Picker("Frequency", selection: $viewModel.draftFrequency) {
                            Text("Weekly").tag(RecurringFrequency.weekly)
                            Text("Bi-weekly").tag(RecurringFrequency.biweekly)
                            Text("Monthly").tag(RecurringFrequency.monthly)
                        }

                        Picker("From Envelope", selection: $sourceEnvelope) {
                            Text("Select an envelope").tag(Envelope?.none)
                            ForEach(accounts) { account in
                                let envelopes = account.envelopes.sorted { $0.name < $1.name }
                                if !envelopes.isEmpty {
                                    Section(account.name) {
                                        ForEach(envelopes) { envelope in
                                            Text(envelope.name).tag(Optional(envelope))
                                        }
                                    }
                                }
                            }
                        }
                        .onChange(of: sourceEnvelope) {
                            if let sourceEnvelope {
                                viewModel.setSource(sourceEnvelope)
                                // Can't also send money to the source itself.
                                viewModel.draftSplits.removeValue(forKey: sourceEnvelope.id)
                                viewModel.calculateUnallocatedFunds()
                            }
                        }
                    }

                    ForEach(accounts) { account in
                        let envelopes = account.envelopes
                            .filter { $0.id != sourceEnvelope?.id }
                            .sorted { $0.name < $1.name }
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
            .navigationTitle(item == nil ? "New Transfer" : "Edit Transfer")
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
                    viewModel.resetDraft(type: .transfer)
                }
                sourceEnvelope = accounts
                    .flatMap { $0.envelopes }
                    .first { $0.id == viewModel.draftSourceEnvelopeID }
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
