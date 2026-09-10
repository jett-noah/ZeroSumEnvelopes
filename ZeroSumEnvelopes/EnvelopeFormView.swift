import SwiftUI

/// Shared form for creating or editing an Envelope — used from both
/// AccountDetailView's toolbar and SettingsView's envelope management list,
/// so envelope creation/editing looks and behaves the same everywhere.
struct EnvelopeFormView: View {
    enum Mode {
        case create
        case edit(Envelope)
    }

    let mode: Mode
    let existingGroups: [String]
    var onSave: (_ name: String, _ groupName: String?, _ targetAmount: Double?, _ targetDate: Date?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var groupChoice: String
    @State private var newGroupName: String = ""
    @State private var hasGoal: Bool
    @State private var targetAmount: Double
    @State private var targetDate: Date

    private static let noGroupTag = "__none__"
    private static let newGroupTag = "__new__"

    init(
        mode: Mode,
        existingGroups: [String],
        onSave: @escaping (_ name: String, _ groupName: String?, _ targetAmount: Double?, _ targetDate: Date?) -> Void
    ) {
        self.mode = mode
        self.existingGroups = existingGroups
        self.onSave = onSave

        switch mode {
        case .create:
            _name = State(initialValue: "")
            _groupChoice = State(initialValue: Self.noGroupTag)
            _hasGoal = State(initialValue: false)
            _targetAmount = State(initialValue: 0)
            _targetDate = State(initialValue: .now)
        case .edit(let envelope):
            _name = State(initialValue: envelope.name)
            if let group = envelope.groupName, existingGroups.contains(group) {
                _groupChoice = State(initialValue: group)
            } else if let group = envelope.groupName {
                _groupChoice = State(initialValue: Self.newGroupTag)
                _newGroupName = State(initialValue: group)
            } else {
                _groupChoice = State(initialValue: Self.noGroupTag)
            }
            _hasGoal = State(initialValue: envelope.targetAmount != nil)
            _targetAmount = State(initialValue: envelope.targetAmount ?? 0)
            _targetDate = State(initialValue: envelope.targetDate ?? .now)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Envelope Name (e.g. \"Groceries\")", text: $name)
                }

                Section {
                    Picker("Group", selection: $groupChoice) {
                        Text("No Group").tag(Self.noGroupTag)
                        ForEach(existingGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                        Text("New Group…").tag(Self.newGroupTag)
                    }

                    if groupChoice == Self.newGroupTag {
                        TextField("Group Name (e.g. \"Fun\")", text: $newGroupName)
                    }
                } header: {
                    Text("Group")
                } footer: {
                    Text("Groups keep related envelopes together, like all your \"Fun\" or \"Car\" envelopes.")
                }

                Section {
                    Toggle("Set a Savings Goal", isOn: $hasGoal.animation())

                    if hasGoal {
                        TextField("Goal Amount", value: $targetAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                        DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Envelope" : "New Envelope")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func resolvedGroupName() -> String? {
        switch groupChoice {
        case Self.noGroupTag:
            return nil
        case Self.newGroupTag:
            let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        default:
            return groupChoice
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        onSave(
            trimmedName,
            resolvedGroupName(),
            hasGoal ? targetAmount : nil,
            hasGoal ? targetDate : nil
        )
        dismiss()
    }
}
