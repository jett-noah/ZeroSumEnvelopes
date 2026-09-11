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

    func refreshShareStatus() {
        cloudShareIsActive = CloudSharingManager.shared.hasActiveShare()
    }
}
