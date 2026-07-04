import Foundation

/// Dormant paywall plumbing. Nothing is gated yet — every check resolves to
/// unlocked. Phase 6 wires up StoreKit (purchasedPro) and sets the real
/// founder cutoff date; until then this is scaffolding only.
enum ProGate {
    /// Users whose first launch predates this are founders: free Pro forever.
    /// Placeholder far-future date so everyone currently qualifies.
    /// One-line change at launch (Phase 6).
    static let founderCutoff: Date = {
        var components = DateComponents()
        components.year = 2027
        components.month = 1
        components.day = 1
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? .distantFuture
    }()

    /// StoreKit 2 purchase state stub — replaced in Phase 6.
    static var purchasedPro = false

    /// Free-tier cap on tracked subscriptions. Unlimited until Phase 6 turns
    /// the paywall on.
    static let freeSubscriptionLimit = Int.max

    static func isFounder(firstLaunchDate: Date) -> Bool {
        firstLaunchDate < founderCutoff
    }

    /// The one check call sites should use. Nil meta (not yet bootstrapped)
    /// falls back to the purchase flag alone.
    static func hasPro(_ meta: AppMeta?) -> Bool {
        guard let meta else { return purchasedPro }
        return isFounder(firstLaunchDate: meta.firstLaunchDate) || purchasedPro
    }
}
