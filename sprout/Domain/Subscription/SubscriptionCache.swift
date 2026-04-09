// sprout/Domain/Subscription/SubscriptionCache.swift
import Foundation

protocol SubscriptionCache {
    var cachedProductID: String? { get set }
    var cachedExpiration: Date? { get set }
    var cachedIsActive: Bool { get set }
    func clear()
}

struct UserDefaultsSubscriptionCache: SubscriptionCache {
    private let defaults: UserDefaults

    init(suiteName: String = "com.firstgrowth.sprout.subscription") {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    var cachedProductID: String? {
        get { defaults.string(forKey: "subscription_product_id") }
        set { defaults.set(newValue, forKey: "subscription_product_id") }
    }

    var cachedExpiration: Date? {
        get { defaults.object(forKey: "subscription_expiration") as? Date }
        set { defaults.set(newValue, forKey: "subscription_expiration") }
    }

    var cachedIsActive: Bool {
        get { defaults.bool(forKey: "subscription_is_active") }
        set { defaults.set(newValue, forKey: "subscription_is_active") }
    }

    func clear() {
        defaults.removeObject(forKey: "subscription_product_id")
        defaults.removeObject(forKey: "subscription_expiration")
        defaults.removeObject(forKey: "subscription_is_active")
    }
}
