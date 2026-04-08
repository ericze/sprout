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

A `@MainActor @Observable` singleton that owns subscription state and provides entitlement checks.

```swift
@MainActor @Observable
final class SubscriptionManager {
    var subscriptionStatus: SubscriptionStatus = .loading
    var products: [StoreKit.Product] = []
    var isLoading: Bool = false

    var isPro: Bool { subscriptionStatus.isActive }
    func isEntitled(_ entitlement: Entitlement) -> Bool

    func loadProducts() async
    func purchase(_ product: StoreKit.Product) async throws -> StoreKit.Transaction?
    func restorePurchases() async
    func listenForTransactions() async  // Transaction.updates stream
}
```

**Lifecycle:**
1. Created once in `ContentView`, injected via `@Environment`
2. `loadProducts()` called on init to fetch product metadata
3. `listenForTransactions()` starts a long-running `Task` observing `Transaction.updates`
4. `subscriptionStatus` drives all UI reactivity

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

- On each successful status update, cache `subscriptionStatus` + `expirationDate` to a dedicated `UserDefaults` suite (`com.firstgrowth.sprout.subscription`)
- On app launch, if StoreKit is unavailable, restore from cache to avoid blocking UI
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

## Sidebar Integration

### New Routes

```swift
// SidebarRoute additions
case cloudSync       // Pro
case familyGroup     // Pro
```

### SidebarIndexItem Extension

```swift
struct SidebarIndexItem: Identifiable {
    let id: SidebarRoute
    let title: String
    let icon: String        // SF Symbol name
    let detail: String
    let isPro: Bool         // NEW: requires Pro entitlement
}
```

### Sidebar Menu Items (full list)

| Route | Title | Icon | Pro |
|-------|-------|------|-----|
| `.language` | Language & Region | `globe` | No |
| `.cloudSync` | Cloud Sync | `cloud` | Yes |
| `.familyGroup` | Family Group | `person.2` | Yes |

### Tap Handling

```swift
func handleIndexItemTap(_ item: SidebarIndexItem) {
    if item.isPro && !subscriptionManager.isPro {
        // Show paywall
        routeState.activeSheet = .paywall
    } else {
        // Navigate to feature page
        navigationPath.append(item.id)
    }
}
```

Pro items display a lock icon (`lock.fill`, `AppTheme.Colors.secondaryText`) on the trailing side.

### Destination Views (Placeholders)

- `CloudSyncView` — placeholder with "Coming soon" for Phase 2
- `FamilyGroupView` — placeholder with "Coming soon" for Phase 3

These exist so navigation works end-to-end for subscribed users. They'll be filled in later phases.

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
| `paywall.feature.family.title` | Family Sharing | 家庭组共享 |
| `paywall.feature.family.detail` | Invite family to co-record | 邀请家人共同记录 |
| `paywall.feature.cloud.title` | Cloud Sync | 云端同步 |
| `paywall.feature.cloud.detail` | Secure data backup | 数据安全备份 |
| `paywall.feature.ai.title` | AI Assistant | AI 智能助手 |
| `paywall.feature.ai.detail` | Food advice, analysis & reports | 辅食建议、分析、周报 |
| `paywall.yearly.badge` | Save 40% | 省 40% |
| `paywall.error.title` | Unable to process | 无法处理 |
| `paywall.restore.empty` | No purchases found | 未找到购买记录 |
| `sidebar.pro.badge` | Pro | Pro |

The existing stale keys (`shell.paywall.*`, `shell.sidebar.family.*`, `shell.sidebar.cloud.*`) will be cleaned up and replaced by these new keys.

## File Structure

### New Files

```
sprout/Domain/Subscription/
├── SubscriptionManager.swift      // Subscription state + StoreKit interaction
├── SubscriptionStatus.swift       // Status enum
├── Entitlement.swift              // Entitlement enum
└── ProductID.swift                // StoreKit product ID constants

sprout/Features/Shell/
├── PaywallView.swift              // Full paywall (replaces PaywallSheet.swift)
├── PaywallFeatureRow.swift        // Reusable feature row component
├── CloudSyncPlaceholderView.swift // "Coming soon" placeholder
└── FamilyGroupPlaceholderView.swift // "Coming soon" placeholder

sprout/Shared/
└── ProBadgeView.swift             // Lock icon / "Pro" badge shared component

sproutTests/
└── SubscriptionManagerTests.swift // Unit tests
```

### Modified Files

| File | Change |
|------|--------|
| `PaywallSheet.swift` | **Delete** — replaced by `PaywallView` |
| `SidebarMenuView.swift` | Add Pro menu items + lock icons + tap handling |
| `SidebarDrawer.swift` | Add `.cloudSync` / `.familyGroup` routes + destinations |
| `SidebarMenuView.swift` (SidebarIndexItem) | Add `isPro` field |
| `AppShellView.swift` | Add Paywall sheet presentation |
| `ContentView.swift` | Create + inject `SubscriptionManager` |
| `Localizable.xcstrings` | Add new L10n keys, clean up stale keys |

## Testing

### Unit Tests (`SubscriptionManagerTests`)

Testable without StoreKit by mocking transaction state:

- `test_notSubscribed_isPro_returnsFalse`
- `test_subscribed_isPro_returnsTrue`
- `test_subscribed_isEntitled_returnsTrue`
- `test_expired_isPro_returnsFalse`
- `test_loadingState_initialValue`
- `test_cachedStatus_restoredOnStartup`

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
