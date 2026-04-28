import Foundation
import StoreKit
@testable import sprout

final class MockProductProvider: ProductProvider, @unchecked Sendable {
    var mockProducts: [Product] = []
    var mockEntitlements: [Transaction] = []
    var mockPurchaseResult: Transaction?
    var shouldThrow = false
    var shouldThrowOnRestore = false
    var didRestore = false

    func fetchProducts(for ids: [String]) async throws -> [Product] {
        mockProducts
    }

    func fetchCurrentEntitlements() async throws -> [Transaction] {
        if shouldThrow {
            throw NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "StoreKit unavailable"])
        }
        return mockEntitlements
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        mockPurchaseResult
    }

    func restorePurchases() async throws {
        if shouldThrowOnRestore {
            throw NSError(domain: "test", code: -2, userInfo: [NSLocalizedDescriptionKey: "Restore unavailable"])
        }
        didRestore = true
    }
}
