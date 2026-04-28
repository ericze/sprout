// sprout/Domain/Subscription/SubscriptionManager.swift
import Foundation
import StoreKit
import Observation

@MainActor @Observable
final class SubscriptionManager {
    private let provider: ProductProvider
    private var cache: SubscriptionCache
    private var transactionListenerTask: Task<Void, Never>?

    var subscriptionStatus: SubscriptionStatus = .loading
    var products: [Product] = []
    var isLoading: Bool = false

    var isPro: Bool {
        subscriptionStatus.isActive
    }

    init(
        provider: ProductProvider? = nil,
        cache: SubscriptionCache? = nil
    ) {
        self.provider = provider ?? StoreKitProvider()
        self.cache = cache ?? UserDefaultsSubscriptionCache()
    }

    func isEntitled(_ entitlement: Entitlement) -> Bool {
        isPro
    }

    func allows(_ capability: ProCapability) -> Bool {
        isPro
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

    func purchase(_ product: Product) async throws -> Transaction? {
        guard let transaction = try await provider.purchase(product) else {
            return nil
        }
        await refreshStatus()
        return transaction
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
            if let active = transactions.first(where: { $0.expirationDate?.compare(.now) == .orderedDescending }) {
                subscriptionStatus = .subscribed(
                    productID: active.productID,
                    expiration: active.expirationDate ?? .distantFuture
                )
                updateCache()
                return
            }

            if let expired = transactions.first(where: { $0.expirationDate != nil }) {
                subscriptionStatus = .expired(gracePeriodEnds: expired.expirationDate)
                updateCache()
                return
            }

            subscriptionStatus = .notSubscribed
            updateCache()
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
