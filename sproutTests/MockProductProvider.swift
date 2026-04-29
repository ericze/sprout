import Foundation
@testable import sprout

final class MockProductProvider: ProductProvider, @unchecked Sendable {
    var mockProducts: [StoreProduct] = []
    var mockEntitlements: [StoreEntitlement] = []
    var purchaseResult: StorePurchaseResult = .pending
    var purchasedProductIDs: [String] = []
    var shouldThrow = false
    var shouldThrowOnRestore = false
    var didRestore = false

    func fetchProducts(for ids: [String]) async throws -> [StoreProduct] {
        mockProducts
    }

    func fetchCurrentEntitlements() async throws -> [StoreEntitlement] {
        if shouldThrow {
            throw NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "StoreKit unavailable"])
        }
        return mockEntitlements
    }

    func purchase(productID: String) async throws -> StorePurchaseResult {
        purchasedProductIDs.append(productID)
        return purchaseResult
    }

    func restorePurchases() async throws {
        if shouldThrowOnRestore {
            throw NSError(domain: "test", code: -2, userInfo: [NSLocalizedDescriptionKey: "Restore unavailable"])
        }
        didRestore = true
    }
}
