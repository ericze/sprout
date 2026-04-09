import Foundation

enum SubscriptionStatus: Equatable {
    case loading
    case notSubscribed
    case subscribed(productID: String, expiration: Date)
    case expired(gracePeriodEnds: Date?)
    case error(String)

    var isActive: Bool {
        if case .subscribed = self { return true }
        return false
    }
}
