// sprout/Domain/Subscription/ProductProvider.swift
import Foundation
import StoreKit

struct StoreProduct: Equatable, Identifiable, Sendable {
    let id: String
    let displayPrice: String
    let price: Decimal
}

struct StoreEntitlement: Equatable, Sendable {
    let productID: String
    let expirationDate: Date?
}

enum StorePurchaseResult: Equatable, Sendable {
    case purchased(StoreEntitlement)
    case cancelled
    case pending
}

enum ProductProviderError: LocalizedError, Equatable {
    case productNotFound(String)

    var errorDescription: String? {
        switch self {
        case .productNotFound(let productID):
            return "StoreKit product not found: \(productID)"
        }
    }
}

/// Protocol abstracting StoreKit product/transaction APIs for testability.
/// The real implementation (StoreKitProvider) delegates to StoreKit 2.
/// Tests use MockProductProvider which returns pre-configured results.
protocol ProductProvider: Sendable {
    func fetchProducts(for ids: [String]) async throws -> [StoreProduct]
    func fetchCurrentEntitlements() async throws -> [StoreEntitlement]
    func purchase(productID: String) async throws -> StorePurchaseResult
    func restorePurchases() async throws
}

struct StoreKitProvider: ProductProvider {
    func fetchProducts(for ids: [String]) async throws -> [StoreProduct] {
        try await Product.products(for: ids)
            .map { product in
                StoreProduct(
                    id: product.id,
                    displayPrice: product.displayPrice,
                    price: product.price
                )
            }
    }

    func fetchCurrentEntitlements() async throws -> [StoreEntitlement] {
        var result: [StoreEntitlement] = []
        for await transaction in Transaction.currentEntitlements {
            if let verified = try? transaction.payloadValue {
                result.append(Self.entitlement(from: verified))
            }
        }
        return result
    }

    func purchase(productID: String) async throws -> StorePurchaseResult {
        guard let product = try await Product.products(for: [productID]).first else {
            throw ProductProviderError.productNotFound(productID)
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            return .purchased(Self.entitlement(from: transaction))
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    private static func entitlement(from transaction: Transaction) -> StoreEntitlement {
        StoreEntitlement(
            productID: transaction.productID,
            expirationDate: transaction.expirationDate
        )
    }
}
