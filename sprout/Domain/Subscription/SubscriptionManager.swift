// sprout/Domain/Subscription/SubscriptionManager.swift
import Foundation
import StoreKit
import Observation

@MainActor @Observable
final class SubscriptionManager {
    private let provider: ProductProvider
    private var cache: SubscriptionCache
    private let nowProvider: () -> Date
    private var transactionListenerTask: Task<Void, Never>?

    var subscriptionStatus: SubscriptionStatus = .loading
    var products: [StoreProduct] = []
    var isLoading: Bool = false

    var isPro: Bool {
        subscriptionStatus.isActive
    }

    init(
        provider: ProductProvider? = nil,
        cache: SubscriptionCache? = nil,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.provider = provider ?? StoreKitProvider()
        self.cache = cache ?? UserDefaultsSubscriptionCache()
        self.nowProvider = nowProvider
    }

    func isEntitled(_ entitlement: Entitlement) -> Bool {
        isPro
    }

    func allows(_ capability: ProCapability) -> Bool {
        isPro
    }

    func canCreateAdditionalBaby(existingBabyCount: Int) -> Bool {
        existingBabyCount == 0 || allows(.multiBaby)
    }

    func loadProducts() async {
        isLoading = true
        do {
            products = try await provider.fetchProducts(for: ProductID.all)
        } catch {
            products = []
        }
        isLoading = false
    }

    func purchase(_ product: StoreProduct) async throws -> StorePurchaseResult {
        let result = try await provider.purchase(productID: product.id)
        switch result {
        case .purchased(let entitlement):
            apply(entitlements: [entitlement])
        case .cancelled, .pending:
            break
        }
        return result
    }

    func restorePurchases() async throws {
        try await provider.restorePurchases()
        await refreshStatus()
    }

    func startListening() {
        guard transactionListenerTask == nil else { return }
        transactionListenerTask = Task { [weak self] in
            for await verificationResult in Transaction.updates {
                guard let self, let transaction = try? verificationResult.payloadValue else { continue }
                await transaction.finish()
                await self.refreshStatus()
            }
        }
    }

    func refreshStatus() async {
        do {
            let transactions = try await provider.fetchCurrentEntitlements()
            apply(entitlements: transactions)
        } catch {
            if cache.cachedIsActive {
                subscriptionStatus = .subscribed(
                    productID: cache.cachedProductID ?? ProductID.monthly,
                    expiration: cache.cachedExpiration ?? .distantFuture
                )
            } else {
                subscriptionStatus = .error(error.localizedDescription)
            }
        }
    }

    private func apply(entitlements: [StoreEntitlement]) {
        let now = nowProvider()

        if let active = entitlements.first(where: { entitlement in
            guard let expirationDate = entitlement.expirationDate else { return true }
            return expirationDate > now
        }) {
            subscriptionStatus = .subscribed(
                productID: active.productID,
                expiration: active.expirationDate ?? .distantFuture
            )
            updateCache()
            return
        }

        if let expired = entitlements.first(where: { $0.expirationDate != nil }) {
            subscriptionStatus = .expired(gracePeriodEnds: expired.expirationDate)
            updateCache()
            return
        }

        subscriptionStatus = .notSubscribed
        updateCache()
    }

    private func updateCache() {
        switch subscriptionStatus {
        case .subscribed(let productID, let expiration):
            cache.cachedProductID = productID
            cache.cachedExpiration = expiration
            cache.cachedIsActive = true
        default:
            cache.cachedIsActive = false
        }
    }
}
