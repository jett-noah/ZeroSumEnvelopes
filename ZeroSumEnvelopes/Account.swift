import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID
    var name: String

    // Deleting an Account cascades and deletes all of its Envelopes.
    @Relationship(deleteRule: .cascade, inverse: \Envelope.account)
    var envelopes: [Envelope] = []

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    /// Not stored directly — always derived from the envelopes underneath it,
    /// so the account balance can never drift out of sync with its envelopes.
    var totalBalance: Double {
        envelopes.reduce(0) { $0 + $1.currentBalance }
    }
}
