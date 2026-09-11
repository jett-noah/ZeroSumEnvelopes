import Foundation
import CloudKit
import SwiftData
import UIKit

@MainActor
final class CloudSharingManager: NSObject {
    static let shared = CloudSharingManager()

    private override init() {}


    func hasActiveShare() -> Bool {
        false
    }

    func presentShare(
        modelContext: ModelContext,
        from presentingViewController: UIViewController,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // SwiftData does not yet have a native way to share the whole
        // store. We are stubbing this out so the app compiles.
        print("Cloud sharing via ModelContext is not natively supported yet.")

        let error = NSError(
            domain: "CloudSharingManager",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Cloud sharing is currently unsupported."]
        )
        completion(.failure(error))
    }
}

extension CloudSharingManager: UICloudSharingControllerDelegate {
    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {}

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {}

    func itemTitle(for csc: UICloudSharingController) -> String? {
        csc.share?[CKShare.SystemFieldKey.title] as? String
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("Failed to save CloudKit share: \(error)")
    }
}
