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
        self.displayName = UserDefaults.standard.string(forKey: displayNameKey) ?? ""
    }

    func saveDisplayName(_ name: String) {
        displayName = name
        UserDefaults.standard.set(name, forKey: displayNameKey)
    }

    // MARK: - Cloud Sharing

    /// The actual UICloudSharingController presentation happens in
    /// SettingsView via CloudSharingManager (it needs a UIViewController to
    /// present from). This just reflects share status back into the UI.
    func refreshShareStatus() {
        cloudShareIsActive = CloudSharingManager.shared.hasActiveShare()
    }
}
