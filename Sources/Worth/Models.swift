import Foundation
import SwiftData

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case monthly, yearly, weekly
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var daysApprox: Double {
        switch self {
        case .weekly: 7
        case .monthly: 30.44
        case .yearly: 365.25
        }
    }
}

enum Verdict {
    case great, okay, waste, noData

    var color: String {
        switch self {
        case .great: "green"
        case .okay: "yellow"
        case .waste: "red"
        case .noData: "gray"
        }
    }
}

@Model
final class Subscription {
    var name: String
    var price: Decimal
    var cycle: BillingCycle
    var actionLabel: String       // "Check In", "Watched", "Used"
    var symbolName: String        // SF Symbol, e.g. "dumbbell.fill"
    var nextDueDate: Date
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \UsageLog.subscription)
    var logs: [UsageLog] = []

    init(name: String, price: Decimal, cycle: BillingCycle = .monthly,
         actionLabel: String = "Used", symbolName: String = "checkmark.circle.fill",
         nextDueDate: Date = .now) {
        self.name = name
        self.price = price
        self.cycle = cycle
        self.actionLabel = actionLabel
        self.symbolName = symbolName
        self.nextDueDate = nextDueDate
        self.createdAt = .now
    }
}

@Model
final class UsageLog {
    var timestamp: Date
    var subscription: Subscription?

    init(timestamp: Date = .now, subscription: Subscription? = nil) {
        self.timestamp = timestamp
        self.subscription = subscription
    }
}

// MARK: - Cost math

extension Subscription {
    /// Uses logged in the current billing period.
    var usesThisPeriod: Int {
        let periodStart = Calendar.current.date(
            byAdding: .day, value: -Int(cycle.daysApprox), to: nextDueDate) ?? .distantPast
        return logs.filter { $0.timestamp >= periodStart }.count
    }

    /// Price divided by uses this period. Nil when never used.
    var costPerUse: Decimal? {
        let uses = usesThisPeriod
        guard uses > 0 else { return nil }
        return price / Decimal(uses)
    }

    var verdict: Verdict {
        guard let cpu = costPerUse else { return .noData }
        // Thresholds relative to price: heavy use = green, 1-2 uses = red-ish.
        let ratio = (cpu / max(price, 0.01)) as NSDecimalNumber
        switch ratio.doubleValue {
        case ..<0.15: return .great      // 7+ uses per period
        case ..<0.5:  return .okay       // 3-6 uses
        default:      return .waste      // 1-2 uses
        }
    }

    /// Annualized price, for the waste headline.
    var annualCost: Decimal {
        switch cycle {
        case .weekly: price * 52
        case .monthly: price * 12
        case .yearly: price
        }
    }
}
