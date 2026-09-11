import Foundation
import SwiftData

@Model
final class Envelope {
    var id: UUID
    var name: String

    var groupName: String?

    var targetAmount: Double?
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
