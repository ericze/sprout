# StoreKit + Paywall Infrastructure (Phase 1 of Family Group Pro)

**Date**: 2026-04-08
**Status**: Draft
**Phase**: 1 of 4 (StoreKit → Auth/Backend → Multi-Baby/Family → AI)

## Background

Sprout is planning a Pro subscription to monetize upcoming features: multi-baby management, family group sharing, cloud sync, and AI-powered tools. This spec covers Phase 1 — the StoreKit 2 subscription infrastructure and paywall UI, with no backend dependency.

The app currently has:
- A `PaywallSheet.swift` stub (deprecated, renders `EmptyView`)
- Stale localization keys for Pro features (`shell.paywall.*`, `shell.sidebar.family.*`, `shell.sidebar.cloud.*`)
- No StoreKit integration, no subscription model, no entitlement checks
- An extensible sidebar (`SidebarRoute` enum, `SidebarIndexItem` list)

## Product Definition

### Subscription Products

| Product | StoreKit Product ID | Billing |
|---------|---------------------|---------|
| Monthly | `com.firstgrowth.sprout.pro.monthly` | ¥18/month |
| Yearly | `com.firstgrowth.sprout.pro.yearly` | ¥128/year (~40% discount) |

Product IDs are namespaced constants in `ProductID.swift`. Actual pricing is configured in App Store Connect; the app reads it via StoreKit at runtime.

### Entitlements

Pro subscribers unlock all entitlements. There is no tiered model.

| Entitlement | Free | Pro |
|-------------|------|-----|
| Record daily activities (milk/sleep/food/height-weight) | 1 baby | Multiple babies |
| Growth curves | Yes | Yes |
| Treasure / weekly letter | Yes | Yes |
| AI food advice | — | Pro |
| AI record analysis | — | Pro |
| AI weekly report | — | Pro |
| Cloud sync | — | Pro |
| Family group sharing | — | Pro |

```swift
enum Entitlement: String, CaseIterable {
    case multiBaby
    case aiFoodAdvice
    case aiRecordAnalysis
    case aiWeeklyReport
    case cloudSync
    case familyGroup
}
```

## Architecture

### SubscriptionManager

A `@MainActor @Observable` class that owns subscription state and provides entitlement checks. Uses constructor injection with protocol-based dependencies for testability.

```swift
// Protocol abstracting StoreKit APIs for testability
protocol ProductProvider: Sendable {
    func products(for ids: [String]) async throws -> [StoreKit.Product]
    func currentEntitlements() async -> StoreKit.Transaction.AsynchronousSequence
    func listenForTransactions() -> StoreKit.Transaction.AsynchronousSequence
}

// Default implementation using real StoreKit
struct StoreKitProvider: ProductProvider { ... }

@MainActor @Observable
final class SubscriptionManager {
    private let provider: ProductProvider
    private let cache: SubscriptionCache
    private var transactionListenerTask: Task<Void, Never>?

    var subscriptionStatus: SubscriptionStatus = .loading
    var products: [StoreKit.Product] = []
    var isLoading: Bool = false

    init(provider: ProductProvider = StoreKitProvider(),
         cache: SubscriptionCache = UserDefaultsSubscriptionCache()) {
        self.provider = provider
        self.cache = cache
    }

    var isPro: Bool { subscriptionStatus.isActive }
    func isEntitled(_ entitlement: Entitlement) -> Bool

    func loadProducts() async
    func purchase(_ product: StoreKit.Product) async throws -> StoreKit.Transaction?
    func restorePurchases() async
    func startListening()  // Starts transactionListenerTask (runs for app lifetime, never cancelled)
}
```

**Lifecycle:**
1. Created once in `ContentView` with default `StoreKitProvider`; tests inject a mock provider
2. Injected via `@Environment` throughout the view hierarchy
3. `loadProducts()` called on init to fetch product metadata
4. `startListening()` starts a long-running `Task` observing `Transaction.updates` — this Task lives for the entire app lifecycle and is never cancelled (expected for a singleton-scoped manager)
5. `subscriptionStatus` drives all UI reactivity

### SubscriptionStatus

```swift
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

**Status resolution order:**
1. Check `Transaction.currentEntitlements` for active transactions
2. If active transaction found → `.subscribed(productID:expiration:)`
3. If expired but within grace period → `.expired(gracePeriodEnds:)`
4. If no transaction → `.notSubscribed`
5. If StoreKit API fails → fall back to cached status from `UserDefaults`; if no cache → `.error(message)`

### Caching

Cache uses a dedicated `UserDefaults` suite (`com.firstgrowth.sprout.subscription`). The `SubscriptionCache` protocol abstracts this for testing.

**Cached fields (flat representation):**
- `subscription_product_id: String?` — product ID of active subscription
- `subscription_expiration: Date?` — expiration date
- `subscription_is_active: Bool` — whether subscription was active when cached

```swift
protocol SubscriptionCache {
    var cachedProductID: String? { get set }
    var cachedExpiration: Date? { get set }
    var cachedIsActive: Bool { get set }
    func clear()
}

struct UserDefaultsSubscriptionCache: SubscriptionCache {
    private let defaults = UserDefaults(suiteName: "com.firstgrowth.sprout.subscription")!
    // ... property accessors mapping to the keys above
}
```

- On each successful status update, write the flat fields
- On app launch, if StoreKit is unavailable, reconstruct status from cached fields
- Cache is informational only — StoreKit is always the source of truth when available

### Error Handling

| Scenario | Behavior |
|----------|----------|
| Network unavailable during product load | `products` stays empty, Paywall shows loading state, retry button |
| StoreKit unavailable | Use cached status, degrade to free mode if no cache |
| Purchase fails (user cancelled) | No-op, no error UI |
| Purchase fails (system error) | Toast with localized error message |
| Restore finds no purchases | Toast: "No purchases found" |
| App Store receipt validation issue | Treat as not subscribed, prompt restore |

## Paywall UI

### PaywallView

Replaces the existing `PaywallSheet` stub. Full-screen modal presentation.

**Layout (top to bottom):**
1. Close button (top-left, `X` icon)
2. App icon + "Sprout Pro" title + tagline
3. Feature list (4 rows with icons, titles, descriptions)
4. Plan selector (monthly vs yearly toggle/picker, yearly shows discount badge)
5. Subscribe button (primary, uses `AppTheme.Colors.accent`)
6. Footer: "Restore Purchases" link + Terms + Privacy

**Feature rows:**

| Icon | Title | Description |
|------|-------|-------------|
| `figure.2.and.child` | Multi-Baby | Track multiple babies |
| `person.2` | Family Sharing | Invite family to co-record |
| `cloud` | Cloud Sync | Secure data backup |
| `brain` | AI Assistant | Food advice, analysis, weekly reports |

**Styling:** Follows `AppTheme` design tokens — `AppTheme.Colors.accent` for primary elements, `AppTheme.Typography.cardTitle` / `.sheetBody` / `.meta` for text hierarchy, `AppTheme.Spacing.screenHorizontal` for padding, `AppTheme.Radius.card` for feature row corners.

### Trigger Points

| Location | Trigger | Behavior |
|----------|---------|----------|
| Sidebar Pro items | Tap locked menu item | Show Paywall as sheet |
| In-feature intercept | Tap Pro-gated feature | Show Paywall as sheet |
| Post-onboarding | After onboarding completes | Optional Pro recommendation (future) |

## Paywall Presentation

The Paywall is presented as a sheet. `AppShellView` owns the sheet state:

```swift
// AppShellView
@Environment(SubscriptionManager.self) private var subscriptionManager
@State private var showPaywall = false

// .sheet(isPresented: $showPaywall) { PaywallView(subscriptionManager: subscriptionManager) }
```

**Trigger flow from Sidebar:**
1. `SidebarMenuView` detects Pro item tap
2. Calls `onProFeatureTap: () -> Void` callback (new parameter)
3. `SidebarDrawer` forwards to `AppShellView` via another callback
4. `AppShellView` sets `showPaywall = true`

The existing `onNavigate` callback is unchanged for normal (non-Pro) navigation. The new `onProFeatureTap` callback is the sole mechanism for Paywall triggers from the sidebar. This keeps `SidebarMenuView` free of `SubscriptionManager` knowledge.

## Sidebar Integration

### New Routes

```swift
// SidebarRoute additions
case cloudSync       // Pro
case familyGroup     // Pro
```

### SidebarIndexItem Extension

The existing `SidebarIndexItem` has fields: `id: String`, `title: String`, `detail: String`, `route: SidebarRoute`. Two new fields are added:

```swift
struct SidebarIndexItem: Identifiable {
    let id: String              // unchanged
    let title: String           // unchanged
    let detail: String          // unchanged
    let route: SidebarRoute     // unchanged
    let icon: String            // NEW — SF Symbol name (e.g. "globe", "cloud", "person.2")
    let isPro: Bool             // NEW — requires Pro entitlement
}
```

All existing and new items in `SidebarIndexItem.items` must provide an `icon` value. The existing `.language` item gains `icon: "globe"`.

### Sidebar Menu Items (full list)

| Route | Title | Icon | Pro |
|-------|-------|------|-----|
| `.language` | Language & Region | `globe` | No |
| `.cloudSync` | Cloud Sync | `cloud` | Yes |
| `.familyGroup` | Family Group | `person.2` | Yes |

### Tap Handling

`SidebarMenuView` receives both `onNavigate: (SidebarRoute) -> Void` (existing) and `onProFeatureTap: (SidebarRoute) -> Void` (new) callbacks. It does NOT hold a reference to `SubscriptionManager`. The route is passed through the callback so `AppShellView` knows which feature to navigate to after subscription.

```swift
// In SidebarMenuView
func handleIndexItemTap(_ item: SidebarIndexItem) {
    if item.isPro {
        onProFeatureTap(item.route)  // Pass route to AppShellView
    } else {
        onNavigate(item.route)
    }
}

// In AppShellView (receives the callback chain)
func handleProFeatureTap(_ route: SidebarRoute) {
    if subscriptionManager.isPro {
        // Navigate to the Pro feature
        sidebarNavigationPath.append(route)
    } else {
        showPaywall = true
    }
}
```

**Sidebar item row layout:** Each row wraps content in an `HStack`. Non-Pro items show title + detail (existing). Pro items add a trailing `Spacer` + `Image(systemName: "lock.fill")` in `AppTheme.Colors.secondaryText`.

### Destination Views (Placeholders)

- `CloudSyncPlaceholderView` — placeholder with "Coming soon" for Phase 2
- `FamilyGroupPlaceholderView` — placeholder with "Coming soon" for Phase 3

These exist so navigation works end-to-end for subscribed users. They'll be filled in later phases.

**SidebarDrawer `navigationDestination` update:**
```swift
// In SidebarDrawer, add to existing navigationDestination switch:
.navigationDestination(for: SidebarRoute.self) { route in
    switch route {
    case .babyProfile:
        BabyProfileView(...)
    case .language:
        LanguageRegionView()
    case .cloudSync:           // NEW
        CloudSyncPlaceholderView()
    case .familyGroup:         // NEW
        FamilyGroupPlaceholderView()
    }
}
```

For subscribed users, tapping a Pro sidebar item navigates normally to the placeholder. For non-subscribers, the Paywall intercepts before navigation (see Tap Handling above).

## New L10n Keys

All new user-facing strings require en + zh:

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

The existing stale keys `shell.sidebar.cloud.title/detail` and `shell.sidebar.family.title/detail` will be **reused** for sidebar menu items (their `extractionState` changed from "stale" to "extracted_with_value"). These serve the sidebar labels. The Paywall uses its own `paywall.feature.cloud.*` and `paywall.feature.family.*` keys (which may have slightly different wording suitable for the paywall marketing context). The stale `shell.paywall.*` keys will be removed and replaced by the new `paywall.*` keys above.

## File Structure

### New Files

```
sprout/Domain/Subscription/
├── SubscriptionManager.swift      // Subscription state + StoreKit interaction
├── SubscriptionStatus.swift       // Status enum
├── Entitlement.swift              // Entitlement enum
├── ProductID.swift                // StoreKit product ID constants
├── ProductProvider.swift          // Protocol + StoreKitProvider (real impl)
└── SubscriptionCache.swift        // Protocol + UserDefaultsSubscriptionCache

sprout/Features/Shell/
├── PaywallView.swift              // Full paywall (replaces PaywallSheet.swift)
├── PaywallFeatureRow.swift        // Reusable feature row component
├── CloudSyncPlaceholderView.swift // "Coming soon" placeholder
└── FamilyGroupPlaceholderView.swift // "Coming soon" placeholder

sprout/Shared/
└── ProBadgeView.swift             // Lock icon / "Pro" badge shared component

sproutTests/
├── SubscriptionManagerTests.swift // Unit tests with MockProductProvider
├── MockProductProvider.swift      // Mock for StoreKit APIs
└── MockSubscriptionCache.swift    // Mock for cache layer
```

### Modified Files

| File | Change |
|------|--------|
| `PaywallSheet.swift` | **Delete** — replaced by `PaywallView` (no other files reference this stub) |
| `SidebarMenuView.swift` | Add Pro menu items + lock icons + `onProFeatureTap` callback; extend `SidebarIndexItem` with `isPro: Bool` + `route: SidebarRoute` fields |
| `SidebarDrawer.swift` | Add `.cloudSync` / `.familyGroup` routes + `navigationDestination` cases for placeholder views; forward `onProFeatureTap` |
| `AppShellView.swift` | Add `@State showPaywall` + `.sheet` for PaywallView; receive `onProFeatureTap` callback chain; subscription check logic |
| `ContentView.swift` | Create `SubscriptionManager` (with default `StoreKitProvider`) + inject via `@Environment` |
| `Localizable.xcstrings` | Add new L10n keys, clean up stale `shell.paywall.*` / `shell.sidebar.family.*` / `shell.sidebar.cloud.*` keys |

**Note:** `SubscriptionManager` is created in `ContentView` (not `SproutApp`) for Phase 1. If Pro status is needed during onboarding in a future phase, the creation point would move up to `SproutApp`.

**Environment injection pattern:**
```swift
// ContentView
@State private var subscriptionManager = SubscriptionManager()

var body: some View {
    AppShellView(...)
        .environment(subscriptionManager)  // Inject for all descendants
}

// Any consuming view
@Environment(SubscriptionManager.self) private var subscriptionManager
```

This is a new pattern for this project (existing stores like `HomeStore` use explicit property passing). `SubscriptionManager` uses `@Environment` because it's needed across multiple feature boundaries (sidebar, paywall, future feature gates) — unlike feature-specific stores that are scoped to one module.

## Testing

### Unit Tests (`SubscriptionManagerTests`)

All tests inject a `MockProductProvider` and `MockSubscriptionCache` to avoid StoreKit dependency:

**SubscriptionManager logic tests:**
- `test_notSubscribed_isPro_returnsFalse`
- `test_subscribed_isPro_returnsTrue`
- `test_subscribed_isEntitled_returnsTrue`
- `test_expired_isPro_returnsFalse`
- `test_loadingState_initialValue`
- `test_cachedStatus_restoredOnStartup`
- `test_cacheUpdatedOnStatusChange`

**Paywall logic tests:**
- `test_productSelection_switchesPlan`
- `test_subscribeButton_disabledWhenLoading`

**Sidebar Pro item tests:**
- `test_proItems_showLockIcon`
- `test_proItemTap_notSubscribed_triggersPaywall`
- `test_proItemTap_subscribed_navigates`

### StoreKit Testing

- Create a `.storekit` configuration file in the project for local testing
- Xcode's StoreKit testing in Simulator and sandbox environment
- Test: purchase flow, restore, subscription expiry, grace period

## Xcode Project Configuration

1. **App Store Connect**: Create subscription group with monthly + yearly products
2. **StoreKit Configuration File**: Add `Products.storekit` to project for local testing
3. **Capabilities**: Verify In-App Purchase capability is enabled
4. **Sandbox**: Configure sandbox test accounts for testing

## Scope Boundaries

### In Scope (Phase 1)
- StoreKit 2 subscription infrastructure
- SubscriptionManager with caching and error handling
- PaywallView with feature list and purchase flow
- Sidebar Pro items with lock icons
- Placeholder destination views
- L10n keys (en + zh)
- Unit tests + StoreKit testing setup

### Out of Scope (Future Phases)
- Backend integration (Phase 2: Supabase + Auth + Cloud Sync)
- Multi-baby management (Phase 3)
- Family group sharing (Phase 3)
- AI features (Phase 4)
- Server-side receipt validation
- Introductory offers / free trials
- Promotional offers / win-back campaigns

## Open Questions

None. All design decisions were resolved during brainstorming.
