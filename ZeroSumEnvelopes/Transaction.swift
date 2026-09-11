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

    var userDisplayName: String

    var envelope: Envelope?

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
