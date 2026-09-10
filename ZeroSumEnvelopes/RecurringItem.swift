import Foundation
import SwiftData

enum RecurringItemType: String, Codable {
    case paycheck
    case subscription
    case transfer
}

enum RecurringFrequency: String, Codable {
    case weekly
    case biweekly
    case monthly
}

@Model
final class RecurringItem {
    var id: UUID
    var title: String
    var type: RecurringItemType
    var nextExecutionDate: Date
    var frequency: RecurringFrequency

    var totalAmount: Double

    /// Maps an Envelope's `id.uuidString` to a fixed dollar amount to send
    /// there. For a subscription or transfer this is just one entry at
    /// 100% of totalAmount (the transfer's destination). For a paycheck
    /// this is the zero-sum split the user builds in PaycheckSetupView.
    var splits: [String: Double]

    /// Only set when type == .transfer — the envelope funds move OUT of.
    /// Paychecks have no source (money originates outside the budget);
    /// a subscription's "source" is implicit — an expense leaving the
    /// budget rather than moving between envelopes.
    var sourceEnvelopeIDString: String?

    init(
        id: UUID = UUID(),
        title: String,
        type: RecurringItemType,
        nextExecutionDate: Date,
        frequency: RecurringFrequency,
        totalAmount: Double,
        splits: [String: Double] = [:],
        sourceEnvelopeIDString: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.nextExecutionDate = nextExecutionDate
        self.frequency = frequency
        self.totalAmount = totalAmount
        self.splits = splits
        self.sourceEnvelopeIDString = sourceEnvelopeIDString
    }

    var allocatedTotal: Double {
        splits.values.reduce(0, +)
    }

    /// Subscriptions and transfers are always considered valid (single
    /// destination, nothing to balance). Paychecks must exactly zero out —
    /// floating point tolerance kept tight (half a cent) so real currency
    /// rounding doesn't accidentally block a valid split.
    var isZeroSumValid: Bool {
        switch type {
        case .subscription, .transfer:
            return true
        case .paycheck:
            return abs(allocatedTotal - totalAmount) < 0.005
        }
    }
}
