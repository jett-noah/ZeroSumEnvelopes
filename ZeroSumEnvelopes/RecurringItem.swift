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

    var splits: [String: Double]

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

    var isZeroSumValid: Bool {
        switch type {
        case .subscription, .transfer:
            return true
        case .paycheck:
            return abs(allocatedTotal - totalAmount) < 0.005
        }
    }
}
