import Foundation
import SwiftData

@Model
final class Envelope {
    var id: UUID
    var name: String

    /// User-assigned grouping label (e.g. "Fun", "Car") so related
    /// envelopes can be shown together. nil means ungrouped.
    var groupName: String?

    /// Optional goal amount for sinking funds (e.g. "Vacation: $2,000").
    var targetAmount: Double?
    /// Optional deadline paired with targetAmount (e.g. "by June 1").
    var targetDate: Date?

    // The parent Account. Inverse of Account.envelopes.
    var account: Account?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.envelope)
    var transactions: [Transaction] = []

    @Relationship(inverse: \Transaction.destinationEnvelope)
    var incomingTransfers: [Transaction] = []

    init(
        id: UUID = UUID(),
        name: String,
        groupName: String? = nil,
        targetAmount: Double? = nil,
        targetDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.groupName = groupName
        self.targetAmount = targetAmount
        self.targetDate = targetDate
    }

    var currentBalance: Double {
        let ownedTotal = transactions.reduce(0.0) { partial, transaction in
            switch transaction.type {
            case .income:
                return partial + transaction.amount
            case .expense, .transfer:
                return partial - transaction.amount
            }
        }
        let incomingTransferTotal = incomingTransfers.reduce(0.0) { $0 + $1.amount }
        return ownedTotal + incomingTransferTotal
    }

    var isOverdrafted: Bool {
        currentBalance < 0
    }
}
