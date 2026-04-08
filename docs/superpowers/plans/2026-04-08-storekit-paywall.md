# StoreKit + Paywall Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build StoreKit 2 subscription infrastructure with paywall UI and sidebar Pro item integration.

**Architecture:** Protocol-based dependency injection for testability. `SubscriptionManager` (created in `ContentView`, injected via `@Environment`) owns subscription state and entitlement checks. `PaywallView` is a full-screen sheet triggered by Pro sidebar item taps. `SidebarDrawer` owns the Pro check logic (receives `SubscriptionManager` via `@Environment` + `onShowPaywall` callback from `AppShellView`).

**Tech Stack:** StoreKit 2, SwiftUI, SwiftData (existing), XCTest

**Spec:** `docs/superpowers/specs/2026-04-08-storekit-paywall-design.md`

**Spec Deviations:**
- `ProductProvider` protocol returns `[Transaction]` instead of `AsyncSequence` and includes `purchase()`/`restorePurchases()` — this is an intentional improvement for testability over the spec's original design.
- `SidebarMenuView` has only `onNavigate` (no `onProFeatureTap`). Pro item logic lives in `SidebarDrawer`. This is simpler than the spec's two-callback design and avoids the cross-layer navigation problem.
- `SidebarIndexItem` does NOT include `icon` field in Phase 1 (unused in current sidebar UI layout).

---

## File Map

### New Files

| File | Responsibility |
|------|---------------|
| `sprout/Domain/Subscription/Entitlement.swift` | Entitlement enum |
| `sprout/Domain/Subscription/ProductID.swift` | StoreKit product ID constants |
| `sprout/Domain/Subscription/SubscriptionStatus.swift` | Subscription status enum with `isActive` |
| `sprout/Domain/Subscription/SubscriptionCache.swift` | Cache protocol + `UserDefaultsSubscriptionCache` |
| `sprout/Domain/Subscription/ProductProvider.swift` | StoreKit protocol + `StoreKitProvider` real implementation |
| `sprout/Domain/Subscription/SubscriptionManager.swift` | Main subscription state manager |
| `sprout/Shared/ProBadgeView.swift` | Lock icon / "Pro" badge shared component |
| `sprout/Features/Shell/PaywallFeatureRow.swift` | Feature row component for Paywall |
| `sprout/Features/Shell/PaywallView.swift` | Full paywall view (replaces PaywallSheet) |
| `sprout/Features/Shell/CloudSyncPlaceholderView.swift` | "Coming soon" placeholder |
| `sprout/Features/Shell/FamilyGroupPlaceholderView.swift` | "Coming soon" placeholder |
| `sproutTests/MockSubscriptionCache.swift` | Mock cache for tests |
| `sproutTests/MockProductProvider.swift` | Mock StoreKit provider for tests |
| `sproutTests/SubscriptionManagerTests.swift` | Unit tests |

### Modified Files

| File | Change |
|------|--------|
| `sprout/Features/Shell/SidebarDrawer.swift` | Add `SidebarRoute.cloudSync/.familyGroup`, extend `SidebarIndexItem` with `isPro`, add Pro items, add `onShowPaywall` callback, add `@Environment SubscriptionManager` for Pro check |
| `sprout/Features/Shell/SidebarMenuView.swift` | Add Pro item row layout with lock icon (no API change — still only `onNavigate`) |
| `sprout/Features/Shell/AppShellView.swift` | Add `@Environment SubscriptionManager`, `showPaywall` state, paywall sheet, pass `onShowPaywall` to `SidebarDrawer` |
| `sprout/ContentView.swift` | Create `SubscriptionManager`, inject via `.environment()` |
| `sprout/Localization/Localizable.xcstrings` | Add new L10n keys, clean up stale keys |

### Deleted Files

| File | Reason |
|------|--------|
| `sprout/Features/Shell/PaywallSheet.swift` | Replaced by `PaywallView` |

---

## Task 1: Entitlement + ProductID + SubscriptionStatus (Domain Types)

**Files:**
- Create: `sprout/Domain/Subscription/Entitlement.swift`
- Create: `sprout/Domain/Subscription/ProductID.swift`
- Create: `sprout/Domain/Subscription/SubscriptionStatus.swift`

- [ ] **Step 1: Create Entitlement enum**

```swift
// sprout/Domain/Subscription/Entitlement.swift
import Foundation

enum Entitlement: String, CaseIterable {
    case multiBaby
    case aiFoodAdvice
    case aiRecordAnalysis
    case aiWeeklyReport
    case cloudSync
    case familyGroup
}
```

- [ ] **Step 2: Create ProductID constants**

```swift
// sprout/Domain/Subscription/ProductID.swift
import Foundation

enum ProductID {
    static let monthly = "com.firstgrowth.sprout.pro.monthly"
    static let yearly = "com.firstgrowth.sprout.pro.yearly"

    static var all: [String] { [monthly, yearly] }
}
```

- [ ] **Step 3: Create SubscriptionStatus enum**

```swift
// sprout/Domain/Subscription/SubscriptionStatus.swift
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
```

- [ ] **Step 4: Commit**

```bash
git add sprout/Domain/Subscription/Entitlement.swift sprout/Domain/Subscription/ProductID.swift sprout/Domain/Subscription/SubscriptionStatus.swift
git commit -m "feat: add subscription domain types (Entitlement, ProductID, SubscriptionStatus)"
```

---

## Task 2: SubscriptionCache (Protocol + UserDefaults Implementation)

**Files:**
- Create: `sprout/Domain/Subscription/SubscriptionCache.swift`

- [ ] **Step 1: Write the cache protocol and UserDefaults implementation**

Note: `cachedIsActive` uses `UserDefaults.bool(forKey:)` which returns `false` for missing keys. This is acceptable because the cache fallback path only triggers on StoreKit API errors (not empty results), and `false` correctly degrades to free mode when cache state is ambiguous.

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add sprout/Domain/Subscription/SubscriptionCache.swift
git commit -m "feat: add SubscriptionCache protocol with UserDefaults implementation"
```

---

## Task 3: ProductProvider (Protocol + StoreKit Implementation)

**Files:**
- Create: `sprout/Domain/Subscription/ProductProvider.swift`

- [ ] **Step 1: Write the StoreKit abstraction protocol and real implementation**

```swift
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
    func restorePurchases() async
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

    func restorePurchases() async {
        try? await AppStore.sync()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add sprout/Domain/Subscription/ProductProvider.swift
git commit -m "feat: add ProductProvider protocol with StoreKit 2 implementation"
```

---

## Task 4: SubscriptionManager

**Files:**
- Create: `sprout/Domain/Subscription/SubscriptionManager.swift`

- [ ] **Step 1: Write the SubscriptionManager**

```swift
// sprout/Domain/Subscription/SubscriptionManager.swift
import Foundation
import StoreKit
import Observation

@MainActor @Observable
final class SubscriptionManager {
    private let provider: ProductProvider
    private let cache: SubscriptionCache
    private var transactionListenerTask: Task<Void, Never>?

    var subscriptionStatus: SubscriptionStatus = .loading
    var products: [Product] = []
    var isLoading: Bool = false

    var isPro: Bool {
        subscriptionStatus.isActive
    }

    init(
        provider: ProductProvider = StoreKitProvider(),
        cache: SubscriptionCache = UserDefaultsSubscriptionCache()
    ) {
        self.provider = provider
        self.cache = cache
    }

    func isEntitled(_ entitlement: Entitlement) -> Bool {
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

    func restorePurchases() async {
        await provider.restorePurchases()
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
```

- [ ] **Step 2: Commit**

```bash
git add sprout/Domain/Subscription/SubscriptionManager.swift
git commit -m "feat: add SubscriptionManager with StoreKit 2 integration"
```

---

## Task 5: Test Infrastructure (Mocks + Unit Tests)

**Files:**
- Create: `sproutTests/MockSubscriptionCache.swift`
- Create: `sproutTests/MockProductProvider.swift`
- Create: `sproutTests/SubscriptionManagerTests.swift`

- [ ] **Step 1: Write MockSubscriptionCache**

```swift
// sproutTests/MockSubscriptionCache.swift
import Foundation
@testable import sprout

final class MockSubscriptionCache: SubscriptionCache {
    var cachedProductID: String?
    var cachedExpiration: Date?
    var cachedIsActive: Bool = false

    func clear() {
        cachedProductID = nil
        cachedExpiration = nil
        cachedIsActive = false
    }
}
```

- [ ] **Step 2: Write MockProductProvider**

Note: `StoreKit.Product` and `StoreKit.Transaction` cannot be constructed in tests. The mock returns empty arrays. Tests that need "subscribed" state set `subscriptionStatus` directly on the manager, testing the enum logic rather than StoreKit parsing.

```swift
// sproutTests/MockProductProvider.swift
import Foundation
import StoreKit
@testable import sprout

final class MockProductProvider: ProductProvider {
    var mockProducts: [Product] = []
    var mockEntitlements: [Transaction] = []
    var mockPurchaseResult: Transaction?
    var shouldThrow = false
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

    func restorePurchases() async {
        didRestore = true
    }
}
```

- [ ] **Step 3: Write SubscriptionManagerTests**

```swift
// sproutTests/SubscriptionManagerTests.swift
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
        manager = SubscriptionManager(provider: provider, cache: cache)
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        XCTAssertTrue(manager.subscriptionStatus == .loading)
    }

    func test_initialState_isPro_isFalse() {
        XCTAssertFalse(manager.isPro)
    }

    // MARK: - Not Subscribed

    func test_notSubscribed_isPro_returnsFalse() async {
        provider.mockEntitlements = []
        await manager.refreshStatus()
        XCTAssertFalse(manager.isPro)
        XCTAssertEqual(manager.subscriptionStatus, .notSubscribed)
    }

    // MARK: - Cache Behavior

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

        // Empty results = not subscribed (cache only used on StoreKit error)
        XCTAssertEqual(manager.subscriptionStatus, .notSubscribed)
    }

    func test_storeKitError_fallsBackToCache() async {
        cache.cachedProductID = ProductID.monthly
        cache.cachedExpiration = Date().addingTimeInterval(86400 * 30)
        cache.cachedIsActive = true

        provider.shouldThrow = true
        await manager.refreshStatus()

        // Falls back to cache since StoreKit threw
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

    // MARK: - Entitlements

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

    // MARK: - Status Transitions

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

    // MARK: - Products

    func test_loadProducts_setsIsLoading_false() async {
        await manager.loadProducts()
        XCTAssertFalse(manager.isLoading)
    }

    // MARK: - Restore

    func test_restorePurchases_callsProvider() async {
        await manager.restorePurchases()
        XCTAssertTrue(provider.didRestore)
    }

    // MARK: - Cache Direct

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
```

- [ ] **Step 4: Run tests**

Run:
```bash
xcodebuild test -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:sproutTests/SubscriptionManagerTests 2>&1 | tail -30
```
Expected: All tests PASS. Some tests may need minor compilation adjustments.

- [ ] **Step 5: Commit**

```bash
git add sproutTests/MockSubscriptionCache.swift sproutTests/MockProductProvider.swift sproutTests/SubscriptionManagerTests.swift
git commit -m "test: add subscription manager unit tests with mock providers"
```

---

## Task 6: ProBadgeView (Shared Component)

**Files:**
- Create: `sprout/Shared/ProBadgeView.swift`

- [ ] **Step 1: Write ProBadgeView**

```swift
// sprout/Shared/ProBadgeView.swift
import SwiftUI

/// Displays a "Pro" badge or lock icon for Pro-gated features.
struct ProBadgeView: View {
    let showLock: Bool

    init(showLock: Bool = true) {
        self.showLock = showLock
    }

    var body: some View {
        if showLock {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.Colors.secondaryText)
        } else {
            Text(L10n.text("sidebar.pro.badge", en: "Pro", zh: "Pro"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.Colors.accent)
                .clipShape(Capsule())
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add sprout/Shared/ProBadgeView.swift
git commit -m "feat: add ProBadgeView shared component"
```

---

## Task 7: Placeholder Views (create before sidebar routes to avoid build break)

**Files:**
- Create: `sprout/Features/Shell/CloudSyncPlaceholderView.swift`
- Create: `sprout/Features/Shell/FamilyGroupPlaceholderView.swift`

These must exist before Task 8 adds `navigationDestination` cases that reference them.

- [ ] **Step 1: Create CloudSyncPlaceholderView**

```swift
// sprout/Features/Shell/CloudSyncPlaceholderView.swift
import SwiftUI

struct CloudSyncPlaceholderView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.section) {
            Spacer()

            Image(systemName: "cloud")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent)

            Text(L10n.text("paywall.coming_soon.title", en: "Coming Soon", zh: "即将上线"))
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(L10n.text("paywall.coming_soon.detail", en: "This feature is under development", zh: "功能开发中，敬请期待"))
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.screenHorizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .navigationTitle(L10n.text("paywall.feature.cloud.title", en: "Cloud Sync", zh: "云端同步"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: Create FamilyGroupPlaceholderView**

```swift
// sprout/Features/Shell/FamilyGroupPlaceholderView.swift
import SwiftUI

struct FamilyGroupPlaceholderView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.section) {
            Spacer()

            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent)

            Text(L10n.text("paywall.coming_soon.title", en: "Coming Soon", zh: "即将上线"))
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(L10n.text("paywall.coming_soon.detail", en: "This feature is under development", zh: "功能开发中，敬请期待"))
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.screenHorizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .navigationTitle(L10n.text("paywall.feature.family.title", en: "Family Group", zh: "家庭组"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add sprout/Features/Shell/CloudSyncPlaceholderView.swift sprout/Features/Shell/FamilyGroupPlaceholderView.swift
git commit -m "feat: add Cloud Sync and Family Group placeholder views"
```

---

## Task 8: Sidebar Extensions (Routes + IndexItem + Pro Items + Navigation)

**Files:**
- Modify: `sprout/Features/Shell/SidebarDrawer.swift`

**Design (finalized):**
- `SidebarMenuView` keeps only `onNavigate` (no Pro-specific callback)
- `SidebarDrawer` adds `onShowPaywall: () -> Void` callback from `AppShellView`
- `SidebarDrawer` receives `SubscriptionManager` via `@Environment`
- When a Pro item is tapped: if subscribed → navigate in `navigationPath`; if not → call `onShowPaywall()`
- `SidebarMenuView` shows lock icon on Pro items (visual only, no logic change)

- [ ] **Step 1: Add new SidebarRoute cases**

In `SidebarDrawer.swift` line 38, add cases:

```swift
// BEFORE:
enum SidebarRoute: Hashable {
    case babyProfile
    case language
}

// AFTER:
enum SidebarRoute: Hashable {
    case babyProfile
    case language
    case cloudSync
    case familyGroup
}
```

- [ ] **Step 2: Extend SidebarIndexItem with `isPro` field and new items**

Replace the `SidebarIndexItem` struct at line 43:

```swift
struct SidebarIndexItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let route: SidebarRoute
    let isPro: Bool

    static var items: [SidebarIndexItem] {
        let service = LocalizationService.current

        return [
            SidebarIndexItem(
                id: "language",
                title: service.string(
                    forKey: "shell.sidebar.language.title",
                    fallback: "Language & Region"
                ),
                detail: service.string(
                    forKey: "shell.sidebar.language.detail",
                    fallback: "Display language and timezone"
                ),
                route: .language,
                isPro: false
            ),
            SidebarIndexItem(
                id: "cloudSync",
                title: service.string(
                    forKey: "shell.sidebar.cloud.title",
                    fallback: "Cloud Sync"
                ),
                detail: service.string(
                    forKey: "shell.sidebar.cloud.detail",
                    fallback: "Secure data backup"
                ),
                route: .cloudSync,
                isPro: true
            ),
            SidebarIndexItem(
                id: "familyGroup",
                title: service.string(
                    forKey: "shell.sidebar.family.title",
                    fallback: "Family Group"
                ),
                detail: service.string(
                    forKey: "shell.sidebar.family.detail",
                    fallback: "Invite family to share records"
                ),
                route: .familyGroup,
                isPro: true
            ),
        ]
    }
}
```

- [ ] **Step 3: Update SidebarDrawer to add `onShowPaywall`, `@Environment SubscriptionManager`, and Pro logic**

Replace the entire `SidebarDrawer` struct:

```swift
struct SidebarDrawer: View {
    let headerConfig: HomeHeaderConfig
    let babyRepository: BabyRepository
    let onShowPaywall: () -> Void
    @Binding var isNavigationAtRoot: Bool
    @Binding var isSidebarOpen: Bool
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            SidebarMenuView(
                headerConfig: headerConfig,
                onNavigate: { route in
                    let item = SidebarIndexItem.items.first { $0.route == route }
                    if let item, item.isPro {
                        if subscriptionManager.isPro {
                            navigationPath.append(route)
                        } else {
                            onShowPaywall()
                        }
                    } else {
                        navigationPath.append(route)
                    }
                }
            )
            .navigationDestination(for: SidebarRoute.self) { route in
                switch route {
                case .babyProfile:
                    BabyProfileView(babyRepository: babyRepository)
                case .language:
                    LanguageRegionView(onLanguageChange: { newLanguage in
                        AppLanguageManager.shared.language = newLanguage
                    })
                case .cloudSync:
                    CloudSyncPlaceholderView()
                case .familyGroup:
                    FamilyGroupPlaceholderView()
                }
            }
        }
        .onChange(of: navigationPath) { _, _ in isNavigationAtRoot = navigationPath.isEmpty }
        .onChange(of: isSidebarOpen) { _, newValue in
            if !newValue {
                navigationPath = NavigationPath()
            }
        }
        .background(AppTheme.Colors.background)
    }
}
```

- [ ] **Step 4: Verify compilation**

Run: `xcodebuild build -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

Note: Will fail because `SidebarMenuView` doesn't show lock icons yet (next step) AND `AppShellView` doesn't pass `onShowPaywall` yet (Task 9). That's expected — the full integration comes together in Tasks 9-10.

- [ ] **Step 5: Commit**

```bash
git add sprout/Features/Shell/SidebarDrawer.swift
git commit -m "feat: extend sidebar with Pro routes, IndexItem isPro, and paywall callback"
```

---

## Task 9: SidebarMenuView (Pro Item Lock Icon UI)

**Files:**
- Modify: `sprout/Features/Shell/SidebarMenuView.swift`

`SidebarMenuView` keeps its simple API (`onNavigate` only). The only change is adding a trailing lock icon for Pro items.

- [ ] **Step 1: Update index card row layout with lock icon for Pro items**

Replace the `ForEach` block in `indexCard` (lines 97-122):

```swift
ForEach(items) { item in
    Button(action: {
        AppHaptics.selection()
        onNavigate(item.route)
    }) {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Text(item.detail)
                    .font(AppTheme.Typography.cardBody)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if item.isPro {
                ProBadgeView(showLock: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)

    if item.id != items.last?.id {
        Divider()
            .overlay(AppTheme.Colors.divider)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add sprout/Features/Shell/SidebarMenuView.swift
git commit -m "feat: add Pro lock icon to sidebar menu items"
```

---

## Task 10: AppShellView (Paywall Sheet + SidebarDrawer Integration)

**Files:**
- Modify: `sprout/Features/Shell/AppShellView.swift`

- [ ] **Step 1: Add SubscriptionManager environment and paywall state**

At the top of `AppShellView`, add `import StoreKit` (line 2). Add inside the struct after line 20:

```swift
@Environment(SubscriptionManager.self) private var subscriptionManager
@State private var showPaywall = false
```

- [ ] **Step 2: Update SidebarDrawer creation to pass `onShowPaywall`**

In `sidebarOverlay` (line 148), update:

```swift
// BEFORE:
SidebarDrawer(
    headerConfig: activeBabyState.headerConfig,
    babyRepository: babyRepository,
    isNavigationAtRoot: $isNavigationAtRoot,
    isSidebarOpen: $showSidebar
)

// AFTER:
SidebarDrawer(
    headerConfig: activeBabyState.headerConfig,
    babyRepository: babyRepository,
    onShowPaywall: { showPaywall = true },
    isNavigationAtRoot: $isNavigationAtRoot,
    isSidebarOpen: $showSidebar
)
```

- [ ] **Step 3: Add Paywall sheet modifier**

After the `ZStack` closing brace in `body` (around line 64), before `.onChange(of: selectedTab)`:

```swift
.sheet(isPresented: $showPaywall) {
    PaywallView()
        .environment(subscriptionManager)
}
```

- [ ] **Step 4: Build and verify**

Run: `xcodebuild build -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

Note: Will fail until `PaywallView` is created (Task 11). This is expected — full build succeeds after Task 11.

- [ ] **Step 5: Commit**

```bash
git add sprout/Features/Shell/AppShellView.swift
git commit -m "feat: integrate paywall sheet and SubscriptionManager in AppShellView"
```

---

## Task 11: PaywallView

**Files:**
- Create: `sprout/Features/Shell/PaywallFeatureRow.swift`
- Create: `sprout/Features/Shell/PaywallView.swift`
- Delete: `sprout/Features/Shell/PaywallSheet.swift`

- [ ] **Step 1: Write PaywallFeatureRow**

```swift
// sprout/Features/Shell/PaywallFeatureRow.swift
import SwiftUI

struct PaywallFeatureRow: View {
    let iconName: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 36, height: 36)
                .background(AppTheme.Colors.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Text(detail)
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }
}
```

- [ ] **Step 2: Write PaywallView**

```swift
// sprout/Features/Shell/PaywallView.swift
import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var selectedPlanIndex: Int = 1  // Default to yearly
    @State private var isPurchasing = false

    private var selectedProduct: Product? {
        guard !subscriptionManager.products.isEmpty else { return nil }
        let sorted = subscriptionManager.products.sorted { $0.price < $1.price }
        guard selectedPlanIndex < sorted.count else { return nil }
        return sorted[selectedPlanIndex]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.Spacing.section) {
                    closeButton
                    heroSection
                    featureList
                    planSelector
                    subscribeButton
                    footer
                }
                .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
                .padding(.bottom, 40)
            }
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
        }
    }

    private var closeButton: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(Circle())
            }
            Spacer()
        }
    }

    private var heroSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent)

            Text(L10n.text("paywall.title", en: "Sprout Pro", zh: "初长 Pro"))
                .font(AppTheme.Typography.sheetTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(L10n.text("paywall.subtitle", en: "Unlock all premium features", zh: "解锁全部高级功能"))
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .padding(.top, 8)
    }

    private var featureList: some View {
        VStack(spacing: 16) {
            PaywallFeatureRow(
                iconName: "figure.2.and.child",
                title: L10n.text("paywall.feature.multibaby.title", en: "Multi-Baby", zh: "多宝宝管理"),
                detail: L10n.text("paywall.feature.multibaby.detail", en: "Track multiple babies", zh: "记录多个宝宝的成长")
            )
            PaywallFeatureRow(
                iconName: "person.2",
                title: L10n.text("paywall.feature.family.title", en: "Family Group", zh: "家庭组"),
                detail: L10n.text("paywall.feature.family.detail", en: "Invite family to co-record", zh: "邀请家人共同记录")
            )
            PaywallFeatureRow(
                iconName: "cloud",
                title: L10n.text("paywall.feature.cloud.title", en: "Cloud Sync", zh: "云端同步"),
                detail: L10n.text("paywall.feature.cloud.detail", en: "Secure data backup", zh: "数据安全备份")
            )
            PaywallFeatureRow(
                iconName: "brain",
                title: L10n.text("paywall.feature.ai.title", en: "AI Assistant", zh: "AI 智能助手"),
                detail: L10n.text("paywall.feature.ai.detail", en: "Food advice, analysis & reports", zh: "辅食建议、分析、周报")
            )
        }
    }

    private var planSelector: some View {
        let products = subscriptionManager.products.sorted { $0.price < $1.price }

        return HStack(spacing: 12) {
            ForEach(Array(products.enumerated()), id: \.offset) { index, product in
                let isYearly = product.id == ProductID.yearly
                planCard(
                    index: index,
                    title: isYearly
                        ? L10n.text("paywall.plan.yearly", en: "Yearly", zh: "年付")
                        : L10n.text("paywall.plan.monthly", en: "Monthly", zh: "月付"),
                    price: product.displayPrice,
                    showsBadge: isYearly
                )
            }
        }
    }

    private func planCard(index: Int, title: String, price: String, showsBadge: Bool) -> some View {
        let isSelected = selectedPlanIndex == index

        return Button(action: { selectedPlanIndex = index }) {
            VStack(spacing: 6) {
                if showsBadge {
                    Text(L10n.text("paywall.yearly.badge", en: "Save 40%", zh: "省 40%"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.accent)
                        .clipShape(Capsule())
                }

                Text(title)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Text(price)
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? AppTheme.Colors.accent.opacity(0.12) : AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .stroke(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.divider, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var subscribeButton: some View {
        Button(action: performPurchase) {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                }
                Text(L10n.text("paywall.subscribe", en: "Subscribe", zh: "订阅"))
                    .font(AppTheme.Typography.primaryButton)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous))
        }
        .disabled(isPurchasing || selectedProduct == nil)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button(action: performRestore) {
                Text(L10n.text("paywall.restore", en: "Restore Purchases", zh: "恢复购买"))
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            HStack(spacing: 16) {
                Link(L10n.text("paywall.terms", en: "Terms of Service", zh: "服务条款"), destination: URL(string: "https://example.com/terms")!)
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)

                Link(L10n.text("paywall.privacy", en: "Privacy Policy", zh: "隐私政策"), destination: URL(string: "https://example.com/privacy")!)
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
    }

    private func performPurchase() {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        Task {
            do {
                _ = try await subscriptionManager.purchase(product)
                dismiss()
            } catch {
                // User cancelled or system error — no-op for cancellation
            }
            isPurchasing = false
        }
    }

    private func performRestore() {
        Task {
            await subscriptionManager.restorePurchases()
        }
    }
}
```

- [ ] **Step 3: Delete PaywallSheet.swift**

```bash
rm sprout/Features/Shell/PaywallSheet.swift
```

Note: After deletion, verify Xcode recognizes the removal. Re-opening the project or building again usually handles this.

- [ ] **Step 4: Build and verify**

Run: `xcodebuild build -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

- [ ] **Step 5: Commit**

```bash
git add sprout/Features/Shell/PaywallFeatureRow.swift sprout/Features/Shell/PaywallView.swift
git rm sprout/Features/Shell/PaywallSheet.swift
git commit -m "feat: implement PaywallView with feature list and plan selector, delete PaywallSheet stub"
```

---

## Task 12: ContentView Integration (Environment Injection)

**Files:**
- Modify: `sprout/ContentView.swift`

- [ ] **Step 1: Create SubscriptionManager and inject via Environment**

Add after line 12 (`private let launchOverrides = ...`):

```swift
@State private var subscriptionManager = SubscriptionManager()
```

Add `.environment(subscriptionManager)` to `AppShellView` (after line 27):

```swift
AppShellView(
    babyRepository: babyRepository,
    store: store,
    growthStore: growthStore,
    treasureStore: treasureStore,
    activeBabyState: activeBabyState,
    initialTab: launchOverrides.initialModule ?? .record
)
.environment(subscriptionManager)
```

In the `.task` block (after `hasBootstrapped = true` at line 39), add:

```swift
await subscriptionManager.loadProducts()
subscriptionManager.startListening()
await subscriptionManager.refreshStatus()
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild build -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

- [ ] **Step 3: Commit**

```bash
git add sprout/ContentView.swift
git commit -m "feat: create SubscriptionManager and inject via @Environment in ContentView"
```

---

## Task 13: L10n Keys (Localization)

**Files:**
- Modify: `sprout/Localization/Localizable.xcstrings`

- [ ] **Step 1: Add new L10n keys to Localizable.xcstrings**

Add all keys from the spec's L10n table. The `Localizable.xcstrings` format is JSON — add entries to the `"strings"` dictionary.

**New keys to add:**

| Key | EN | ZH |
|-----|----|----|
| `paywall.title` | Sprout Pro | 初长 Pro |
| `paywall.subtitle` | Unlock all premium features | 解锁全部高级功能 |
| `paywall.subscribe` | Subscribe | 订阅 |
| `paywall.restore` | Restore Purchases | 恢复购买 |
| `paywall.feature.multibaby.title` | Multi-Baby | 多宝宝管理 |
| `paywall.feature.multibaby.detail` | Track multiple babies | 记录多个宝宝的成长 |
| `paywall.feature.family.title` | Family Group | 家庭组 |
| `paywall.feature.family.detail` | Invite family to co-record | 邀请家人共同记录 |
| `paywall.feature.cloud.title` | Cloud Sync | 云端同步 |
| `paywall.feature.cloud.detail` | Secure data backup | 数据安全备份 |
| `paywall.feature.ai.title` | AI Assistant | AI 智能助手 |
| `paywall.feature.ai.detail` | Food advice, analysis & reports | 辅食建议、分析、周报 |
| `paywall.yearly.badge` | Save 40% | 省 40% |
| `paywall.error.title` | Unable to process | 无法处理 |
| `paywall.restore.empty` | No purchases found | 未找到购买记录 |
| `paywall.loading` | Loading... | 加载中... |
| `paywall.plan.monthly` | Monthly | 月付 |
| `paywall.plan.yearly` | Yearly | 年付 |
| `paywall.success.message` | Welcome to Sprout Pro! | 欢迎使用初长 Pro！ |
| `paywall.terms` | Terms of Service | 服务条款 |
| `paywall.privacy` | Privacy Policy | 隐私政策 |
| `paywall.coming_soon.title` | Coming Soon | 即将上线 |
| `paywall.coming_soon.detail` | This feature is under development | 功能开发中，敬请期待 |
| `sidebar.pro.badge` | Pro | Pro |

**Stale keys to reactivate** (change `extractionState` from `"stale"` to `"extracted_with_value"`):
- `shell.sidebar.cloud.title` / `shell.sidebar.cloud.detail`
- `shell.sidebar.family.title` / `shell.sidebar.family.detail`

**Stale keys to remove:**
- `shell.paywall.title`, `shell.paywall.coming_soon`, `shell.paywall.upgrade`
- `shell.paywall.feature.cloud`, `shell.paywall.feature.family`, `shell.paywall.feature.more`

Since `L10n.text()` calls provide inline fallbacks, the app will compile without the `.xcstrings` entries. The `.xcstrings` entries are needed for the actual localization to work at runtime.

- [ ] **Step 2: Build to trigger string extraction**

Run: `xcodebuild build -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

After building, Xcode extracts new strings into `Localizable.xcstrings`. Then manually add the zh translations for each key.

- [ ] **Step 3: Commit**

```bash
git add sprout/Localization/Localizable.xcstrings
git commit -m "feat: add Pro/Paywall L10n keys (en + zh)"
```

---

## Task 14: Final Integration Test + Cleanup

**Files:**
- All modified files

- [ ] **Step 1: Full build**

Run: `xcodebuild build -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Run all tests**

Run: `xcodebuild test -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: All tests pass

- [ ] **Step 3: Manual smoke test checklist**

1. Launch app → sidebar opens → Cloud Sync item shows lock icon
2. Tap Cloud Sync → Paywall sheet appears
3. Paywall shows features, plan selector, subscribe button
4. Close paywall → back to sidebar
5. Family Group item also shows lock icon, same behavior
6. Language & Region item has no lock icon, navigates normally

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete StoreKit + Paywall Phase 1 integration"
```
