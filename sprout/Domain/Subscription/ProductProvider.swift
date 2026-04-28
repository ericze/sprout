// sprout/Domain/Subscription/ProductProvider.swift
import Foundation
import StoreKit

/// Protocol abstracting StoreKit product/transaction APIs for testability.
/// The real implementation (StoreKitProvider) delegates to StoreKit 2.
/// Tests use MockProductProvider which returns pre-configured results.
///
/// Note: Returns [Transaction] instead of AsyncSequence for simpler mocking.
/// Includes purchase() and restorePurchases() to fully abstract StoreKit.
protocol ProductProvider: Sendable {
    func fetchProducts(for ids: [String]) async throws -> [Product]
    func fetchCurrentEntitlements() async throws -> [Transaction]
    func purchase(_ product: Product) async throws -> StoreKit.Transaction?
    func restorePurchases() async throws
}

struct StoreKitProvider: ProductProvider {
    func fetchProducts(for ids: [String]) async throws -> [Product] {
        try await Product.products(for: ids)
    }

    func fetchCurrentEntitlements() async throws -> [Transaction] {
        var result: [Transaction] = []
        for await transaction in Transaction.currentEntitlements {
            if let verified = try? transaction.payloadValue {
                result.append(verified)
            }
        }
        return result
    }

    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try? verification.payloadValue
            if let transaction {
                await transaction.finish()
            }
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
    }
}
