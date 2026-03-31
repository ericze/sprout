# Sidebar Navigation Design

Date: 2026-03-31

## Overview

Implement functional navigation for the existing sidebar drawer. The sidebar serves as the app's settings entry point, using an X (Twitter)-style in-sidebar navigation stack for secondary pages. Current UI and visual style remain unchanged; only functional logic and secondary pages are added.

## Requirements

| Item | Decision |
|------|----------|
| Positioning | App settings entry (management-oriented) |
| Menu items | profile → Baby Profile, preferences → Language & Region, +Family Group (Pro), +Cloud Sync (Pro) |
| Navigation style | In-sidebar NavigationStack with slide-in secondary pages |
| Pro items | Tap → PaywallSheet (not a push navigation) |
| UI style | Preserve existing AppTheme; secondary pages follow same design tokens |
| Baby profile | Editable + persisted via SwiftData |
| Pro features | V1: paywall UI placeholder only |

## Architecture

### Navigation Stack

```
SidebarDrawer
  └─ NavigationStack
       ├─ Root: SidebarMenuView (existing one-level menu UI, extracted)
       │    ├─ headerCard (baby avatar card)
       │    ├─ indexCard (4 menu items)
       │    └─ footerNote
       ├─ NavigationLink → BabyProfileView
       ├─ NavigationLink → LanguageRegionView
       └─ Pro item tap → .sheet(PaywallSheet)
```

### Route Model

```swift
enum SidebarRoute: Hashable {
    case babyProfile
    case language
}
```

- `SidebarIndexItem` gains a `route: SidebarRoute?` field (Pro items have `nil`, triggering sheet instead)
- `SidebarIndexItem` gains an `isPro: Bool` field

### Sidebar Behavior

| Action | Behavior |
|--------|----------|
| Tap Baby Profile | NavigationLink push |
| Tap Language & Region | NavigationLink push |
| Tap Pro item | `.sheet(PaywallSheet())` |
| Back button (top-left) | `@Environment(\.dismiss)`, custom styled |
| Swipe right to go back | NavigationStack native gesture |
| Sidebar closes | NavigationStack pops to root automatically |

## Data Persistence

### BabyProfile Model

```swift
// sprout/Domain/Baby/BabyProfile.swift
@Model
final class BabyProfile {
    var name: String
    var birthDate: Date
    var gender: Gender?
    var createdAt: Date
    var isActive: Bool  // V1: only one active

    enum Gender: String, Codable {
        case male, female
    }
}
```

- Registered in existing `ModelContainer` alongside `RecordItem`, `MemoryEntry`, `WeeklyLetter`
- V1 creates a single `BabyProfile(isActive: true)` on first launch
- Architecture supports multi-baby without persistence layer changes

### BabyRepository

```swift
// sprout/Domain/Baby/BabyRepository.swift
final class BabyRepository {
    var activeBaby: BabyProfile?
    func save(_ baby: BabyProfile)
    func updateName(_ name: String)
    func updateBirthDate(_ date: Date)
    func updateGender(_ gender: BabyProfile.Gender?)
}
```

- Follows existing Repository pattern (RecordRepository, GrowthRecordRepository, etc.)
- Wraps SwiftData `ModelContext` CRUD

### HomeHeaderConfig Changes

- Dynamically generated from `BabyProfile` instead of hardcoded placeholder
- `ContentView` creates default BabyProfile on first launch if none exists
- Header card in sidebar auto-updates when profile is edited

### ModelContainer Update

`SproutApp.swift`: Add `BabyProfile.self` to schema.

## File Structure

### New Files

| File | Location | Purpose |
|------|----------|---------|
| `BabyProfile.swift` | `sprout/Domain/Baby/` | SwiftData model |
| `BabyRepository.swift` | `sprout/Domain/Baby/` | SwiftData CRUD wrapper |
| `SidebarMenuView.swift` | `sprout/Features/Shell/` | Extracted one-level menu content |
| `BabyProfileView.swift` | `sprout/Features/Shell/` | Baby profile editing page |
| `LanguageRegionView.swift` | `sprout/Features/Shell/` | Language and region settings |
| `PaywallSheet.swift` | `sprout/Features/Shell/` | Pro paywall placeholder sheet |

### Modified Files

| File | Change |
|------|--------|
| `SidebarDrawer.swift` | Wrap in NavigationStack, expand index items to 4, add NavigationLink logic |
| `SidebarIndexItem` (in SidebarDrawer.swift) | Add `isPro: Bool`, `route: SidebarRoute?`, add family/cloud items |
| `HomeModels.swift` | `HomeHeaderConfig` reads from BabyProfile |
| `SproutApp.swift` | Add `BabyProfile.self` to ModelContainer schema |
| `ContentView.swift` | Create default BabyProfile on first launch, inject into stores |

## Secondary Pages

### BabyProfileView

| Field | Control | Notes |
|-------|---------|-------|
| Avatar | Circle monogram (first char) | V1: not editable, V2: image support |
| Nickname | TextField | Save on change via BabyRepository |
| Birth date | DatePicker (.graphical) | Bottom sheet picker |
| Gender | Chip selector (Male / Female) | Optional, defaults to nil |

- Save-on-edit: each field change triggers immediate `BabyRepository.update*()`
- Header card in sidebar updates reactively

### LanguageRegionView

| Field | Control | Notes |
|-------|---------|-------|
| Language | Two-option chip: 中文 / English | `@AppStorage("app_language")`, requires restart |
| Timezone | Follow system (auto) | V1: read-only, follows system setting |

### PaywallSheet

- Simple sheet with Pro feature description + upgrade button
- V1: upgrade button shows "coming soon" toast
- No actual payment integration

## Testing

| Test | Type | Coverage |
|------|------|----------|
| `BabyRepositoryTests` | Unit | CRUD, activeBaby query, field updates |
| `SidebarIndexItem` validation | Unit | 4 items, isPro flags correct |
| `HomeHeaderConfig` generation | Unit | From BabyProfile, placeholder fallback |
| Manual testing | UI | Navigation transitions, swipe-back, Pro sheet, live editing |

- Uses existing `TestEnvironment` (in-memory SwiftData + isolated UserDefaults)
- No UI test infrastructure; navigation verified manually

## Future-Proofing: Multi-Baby

When multi-baby switching is needed:

1. Add baby switcher UI to sidebar header
2. Add `switchTo(_:)` to `BabyRepository`
3. Each Store's `configure()` filters data by active baby
4. **No persistence layer changes needed** — SwiftData already supports multiple `BabyProfile` records
