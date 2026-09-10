import Foundation
import SwiftData

enum TransactionType: String, Codable {
    case income
    case expense
    case transfer
}

@Model
final class Transaction {
    var id: UUID
    var amount: Double
    var date: Date
    var type: TransactionType
    var notes: String
    var tags: [String]

    /// Stamps which household member made this transaction. Since the app
    /// uses native Apple IDs via CloudKit rather than its own auth system,
    /// this is how "who spent what" gets tracked across devices.
    var userDisplayName: String

    // The primary envelope: where income lands, where an expense is
    // deducted from, or the *source* envelope for a transfer.
    var envelope: Envelope?

    // Only set when type == .transfer — the envelope receiving the funds.
    var destinationEnvelope: Envelope?

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date = .now,
        type: TransactionType,
        notes: String = "",
        tags: [String] = [],
        userDisplayName: String,
        envelope: Envelope? = nil,
        destinationEnvelope: Envelope? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.type = type
        self.notes = notes
        self.tags = tags
        self.userDisplayName = userDisplayName
        self.envelope = envelope
        self.destinationEnvelope = destinationEnvelope
    }
}
