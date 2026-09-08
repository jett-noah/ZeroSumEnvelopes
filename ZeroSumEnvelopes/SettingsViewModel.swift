import Foundation
import SwiftData
import Observation

@Observable
final class SettingsViewModel {
    private var modelContext: ModelContext
    private let displayNameKey = "displayName"

    var displayName: String
    var cloudShareIsActive: Bool = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Reads the same UserDefaults key that AddTransactionView's
        // @AppStorage("displayName") reads/writes, so a name set here shows
        // up there without any extra plumbing.
        self.displayName = UserDefaults.standard.string(forKey: displayNameKey) ?? ""
    }

    func saveDisplayName(_ name: String) {
        displayName = name
        UserDefaults.standard.set(name, forKey: displayNameKey)
    }

    // MARK: - Account CRUD

    func createAccount(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Account(name: trimmed))
        save()
    }

    func updateAccount(_ account: Account, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        account.name = trimmed
        save()
    }

    func deleteAccount(_ account: Account) {
        modelContext.delete(account)
        save()
    }

    // MARK: - Envelope CRUD

    func createEnvelope(
        for account: Account,
        name: String,
        targetAmount: Double? = nil,
        targetDate: Date? = nil
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let envelope = Envelope(name: trimmed, targetAmount: targetAmount, targetDate: targetDate)
        envelope.account = account
        modelContext.insert(envelope)
        save()
    }

    func deleteEnvelope(_ envelope: Envelope) {
        modelContext.delete(envelope)
        save()
    }

    // MARK: - Cloud Sharing

    /// The actual UICloudSharingController presentation happens in
    /// SettingsView via CloudSharingManager (it needs a UIViewController to
    /// present from). This just reflects share status back into the UI.
    func refreshShareStatus(for account: Account) {
        cloudShareIsActive = CloudSharingManager.shared.hasActiveShare(for: account)
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("SettingsViewModel save failed: \(error)")
        }
    }
}
