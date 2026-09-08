import Foundation
import SwiftData

enum RecurringItemType: String, Codable {
    case paycheck
    case subscription
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

    /// Total expected amount — the paycheck's take-home pay, or the
    /// subscription's charge amount.
    var totalAmount: Double

    /// Maps an Envelope's `id.uuidString` to a fixed dollar amount to send
    /// there. For a subscription this is just one entry at 100% of
    /// totalAmount. For a paycheck this is the zero-sum split the user
    /// builds in PaycheckSetupView.
    ///
    /// Note: SwiftData stores [String: Double] fine since Double is a
    /// supported Codable value type, but if this ever needs to hold
    /// non-primitive values, switch to an external Data blob instead.
    var splits: [String: Double]

    init(
        id: UUID = UUID(),
        title: String,
        type: RecurringItemType,
        nextExecutionDate: Date,
        frequency: RecurringFrequency,
        totalAmount: Double,
        splits: [String: Double] = [:]
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.nextExecutionDate = nextExecutionDate
        self.frequency = frequency
        self.totalAmount = totalAmount
        self.splits = splits
    }

    var allocatedTotal: Double {
        splits.values.reduce(0, +)
    }

    /// Subscriptions are always considered valid (single destination,
    /// nothing to balance). Paychecks must exactly zero out — floating
    /// point tolerance kept tight (half a cent) so real currency rounding
    /// doesn't accidentally block a valid split.
    var isZeroSumValid: Bool {
        switch type {
        case .subscription:
            return true
        case .paycheck:
            return abs(allocatedTotal - totalAmount) < 0.005
        }
    }
}
