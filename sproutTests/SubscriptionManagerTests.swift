import XCTest
@testable import sprout

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    private var provider: MockProductProvider!
    private var cache: MockSubscriptionCache!
    private var manager: SubscriptionManager!

    override func setUp() {
        provider = MockProductProvider()
        cache = MockSubscriptionCache()
        manager = SubscriptionManager(
            provider: provider,
            cache: cache,
            nowProvider: { Date(timeIntervalSince1970: 1_711_000_000) }
        )
    }

    func test_initialState_isLoading() {
        XCTAssertTrue(manager.subscriptionStatus == .loading)
    }

    func test_initialState_isPro_isFalse() {
        XCTAssertFalse(manager.isPro)
    }

    func test_notSubscribed_isPro_returnsFalse() async {
        provider.mockEntitlements = []
        await manager.refreshStatus()
        XCTAssertFalse(manager.isPro)
        XCTAssertEqual(manager.subscriptionStatus, .notSubscribed)
    }

    func test_notSubscribed_clearsCache() async {
        cache.cachedIsActive = true
        provider.mockEntitlements = []
        await manager.refreshStatus()
        XCTAssertFalse(cache.cachedIsActive)
    }

    func test_emptyEntitlements_notSubscribed() async {
        cache.cachedProductID = ProductID.monthly
        cache.cachedExpiration = Date().addingTimeInterval(86400 * 30)
        cache.cachedIsActive = true
        provider.mockEntitlements = []
        await manager.refreshStatus()
        XCTAssertEqual(manager.subscriptionStatus, .notSubscribed)
    }

    func test_purchaseMonthlySandboxResult_unlocksProAndCachesEntitlement() async throws {
        let expiration = Date(timeIntervalSince1970: 1_711_000_000 + 2_592_000)
        let monthly = StoreProduct(id: ProductID.monthly, displayPrice: "$4.99", price: 4.99)
        provider.mockProducts = [monthly]
        provider.purchaseResult = .purchased(
            StoreEntitlement(productID: ProductID.monthly, expirationDate: expiration)
        )

        let result = try await manager.purchase(monthly)

        XCTAssertEqual(result, .purchased(StoreEntitlement(productID: ProductID.monthly, expirationDate: expiration)))
        XCTAssertEqual(provider.purchasedProductIDs, [ProductID.monthly])
        XCTAssertEqual(manager.subscriptionStatus, .subscribed(productID: ProductID.monthly, expiration: expiration))
        XCTAssertTrue(manager.isPro)
        XCTAssertEqual(cache.cachedProductID, ProductID.monthly)
        XCTAssertEqual(cache.cachedExpiration, expiration)
        XCTAssertTrue(cache.cachedIsActive)
    }

    func test_cancelledSandboxPurchase_doesNotUnlockOrCachePro() async throws {
        let monthly = StoreProduct(id: ProductID.monthly, displayPrice: "$4.99", price: 4.99)
        provider.mockProducts = [monthly]
        provider.purchaseResult = .cancelled

        let result = try await manager.purchase(monthly)

        XCTAssertEqual(result, .cancelled)
        XCTAssertFalse(manager.isPro)
        XCTAssertNil(cache.cachedProductID)
        XCTAssertFalse(cache.cachedIsActive)
    }

    func test_restoreSandboxPurchase_unlocksProFromCurrentEntitlements() async throws {
        let expiration = Date(timeIntervalSince1970: 1_711_000_000 + 31_536_000)
        provider.mockEntitlements = [
            StoreEntitlement(productID: ProductID.yearly, expirationDate: expiration)
        ]

        try await manager.restorePurchases()

        XCTAssertTrue(provider.didRestore)
        XCTAssertEqual(manager.subscriptionStatus, .subscribed(productID: ProductID.yearly, expiration: expiration))
        XCTAssertTrue(manager.isPro)
    }

    func test_expiredSandboxEntitlement_revokesAllProCapabilities() async {
        let expiration = Date(timeIntervalSince1970: 1_711_000_000 - 60)
        provider.mockEntitlements = [
            StoreEntitlement(productID: ProductID.monthly, expirationDate: expiration)
        ]

        await manager.refreshStatus()

        XCTAssertEqual(manager.subscriptionStatus, .expired(gracePeriodEnds: expiration))
        XCTAssertFalse(manager.isPro)
        XCTAssertFalse(manager.allows(.multiBaby))
        XCTAssertFalse(manager.allows(.cloudSync))
        XCTAssertFalse(manager.allows(.familyGroup))
    }

    func test_storeKitError_fallsBackToCache() async {
        cache.cachedProductID = ProductID.monthly
        cache.cachedExpiration = Date().addingTimeInterval(86400 * 30)
        cache.cachedIsActive = true
        provider.shouldThrow = true
        await manager.refreshStatus()
        XCTAssertTrue(manager.isPro)
        if case .subscribed(let productID, _) = manager.subscriptionStatus {
            XCTAssertEqual(productID, ProductID.monthly)
        } else {
            XCTFail("Expected subscribed status from cache")
        }
    }

    func test_storeKitError_noCache_returnsError() async {
        provider.shouldThrow = true
        await manager.refreshStatus()
        XCTAssertFalse(manager.isPro)
        if case .error = manager.subscriptionStatus {
            // Expected
        } else {
            XCTFail("Expected error status")
        }
    }

    func test_isEntitled_whenNotPro_returnsFalse() async {
        provider.mockEntitlements = []
        await manager.refreshStatus()
        XCTAssertFalse(manager.isEntitled(.cloudSync))
        XCTAssertFalse(manager.isEntitled(.familyGroup))
    }

    func test_isEntitled_whenPro_returnsTrue() {
        manager.subscriptionStatus = .subscribed(
            productID: ProductID.monthly,
            expiration: Date().addingTimeInterval(86400 * 30)
        )
        for entitlement in Entitlement.allCases {
            XCTAssertTrue(manager.isEntitled(entitlement))
        }
    }

    func test_allProCapabilities_areDeniedWhenNotSubscribed() async {
        provider.mockEntitlements = []
        await manager.refreshStatus()

        for capability in ProCapability.allCases {
            XCTAssertFalse(manager.allows(capability), "Expected \(capability) to be gated for free users")
        }
    }

    func test_allProCapabilities_areAllowedWhenSubscribed() {
        manager.subscriptionStatus = .subscribed(
            productID: ProductID.monthly,
            expiration: Date().addingTimeInterval(86400 * 30)
        )

        for capability in ProCapability.allCases {
            XCTAssertTrue(manager.allows(capability), "Expected \(capability) to be allowed for Pro users")
        }
    }

    func test_allProCapabilities_areDeniedWhenExpired() {
        manager.subscriptionStatus = .expired(gracePeriodEnds: nil)

        for capability in ProCapability.allCases {
            XCTAssertFalse(manager.allows(capability), "Expected \(capability) to be gated for expired users")
        }
    }

    func test_subscribed_isPro_returnsTrue() {
        manager.subscriptionStatus = .subscribed(
            productID: ProductID.monthly,
            expiration: Date().addingTimeInterval(86400 * 30)
        )
        XCTAssertTrue(manager.isPro)
    }

    func test_expired_isPro_returnsFalse() {
        manager.subscriptionStatus = .expired(gracePeriodEnds: nil)
        XCTAssertFalse(manager.isPro)
    }

    func test_error_isPro_returnsFalse() {
        manager.subscriptionStatus = .error("test error")
        XCTAssertFalse(manager.isPro)
    }

    func test_loadProducts_setsIsLoading_false() async {
        await manager.loadProducts()
        XCTAssertFalse(manager.isLoading)
    }

    func test_restorePurchases_callsProvider() async {
        try? await manager.restorePurchases()
        XCTAssertTrue(provider.didRestore)
    }

    func test_restorePurchases_propagatesProviderError() async {
        provider.shouldThrowOnRestore = true

        do {
            try await manager.restorePurchases()
            XCTFail("Expected restore to throw")
        } catch {
            XCTAssertEqual((error as NSError).domain, "test")
        }
    }

    func test_cache_readWrite() {
        cache.cachedProductID = ProductID.yearly
        cache.cachedExpiration = Date().addingTimeInterval(86400 * 365)
        cache.cachedIsActive = true
        XCTAssertEqual(cache.cachedProductID, ProductID.yearly)
        XCTAssertTrue(cache.cachedIsActive)
        cache.clear()
        XCTAssertNil(cache.cachedProductID)
        XCTAssertFalse(cache.cachedIsActive)
    }
}
