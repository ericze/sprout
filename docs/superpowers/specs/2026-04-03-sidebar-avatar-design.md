# Sidebar Avatar Navigation & Baby Profile Avatar Picker

Date: 2026-04-03

## Overview

Two related changes:
1. Remove "宝宝资料" menu item from sidebar; make the entire header card (avatar + name) tappable to navigate to BabyProfileView.
2. Add avatar photo picker to BabyProfileView, supporting album, camera, and removal.

## Section 1: Sidebar Changes

### Remove profile menu item

Delete `SidebarIndexItem.profile` from the index list. Remaining items: language preferences, family management (Pro), cloud backup (Pro).

### Header card navigation

`SidebarMenuView.headerCard` currently is a `Button { onHeaderTap() }` that closes the sidebar. Change to `Button { onNavigate(.babyProfile) }` which pushes `BabyProfileView` via the sidebar's NavigationStack.

- Remove `onHeaderTap` callback from `SidebarMenuView`.
- Replace with `onNavigate: (SidebarRoute) -> Void` (same callback used by menu items).
- `SidebarRoute` enum unchanged — `.babyProfile` still needed for navigation.

## Section 2: Data Model

### BabyProfile

Add field:
```swift
var avatarPath: String?
```

No separate `BabyAvatarStorage` class. All avatar file I/O is encapsulated in `BabyRepository`.

### BabyRepository

Add method:
```swift
func updateAvatar(_ image: UIImage?)
```

- `UIImage` provided: save JPEG to `ApplicationSupport/BabyAvatars/{uuid}.jpg`, delete old file, update `avatarPath`.
- `nil` provided: delete old file, set `avatarPath = nil`.

File storage logic is a private helper within `BabyRepository`. All baby data (including avatar) managed through a single repository.

### HomeHeaderConfig

Add field:
```swift
var avatarPath: String?
```

`from(_:)` factory populates from `baby.avatarPath`.

## Section 3: BabyProfileView Avatar Picker

### Interaction

Tap the 80x80 avatar circle → `confirmationDialog` with options:

1. **Album**: SwiftUI native `PhotosPicker`, bind to `selectedPhotoItem`. On change, load transferable data, call `babyRepository.updateAvatar(image)`.
2. **Camera**: `.sheet` presenting existing `SystemImagePicker(sourceType: .camera)`. On image captured, call `babyRepository.updateAvatar(image)`.
3. **Remove avatar**: Call `babyRepository.updateAvatar(nil)`. Only shown when `avatarPath != nil`.

### Visual states

- **No avatar**: Current monogram circle + hint text (unchanged).
- **Has avatar**: Circular-clipped avatar image, small edit icon overlay (camera/pencil) at bottom-right.
- Transition animated with `AppTheme.stateAnimation`.

### Data flow

`BabyProfileView` observes `babyRepository.activeBaby.avatarPath`. After photo selection, `babyRepository.updateAvatar(_:)` updates model → UI refreshes automatically.

## Section 4: Global Avatar Display Sync

Three locations display avatars, all need `avatarPath` support:

| Location | File | Size |
|----------|------|------|
| Sidebar header card | `SidebarMenuView.swift` | 56×56 |
| Profile edit page | `BabyProfileView.swift` | 80×80 |
| Top bar button | `MagazineTopBar.swift` | 32×32 |

### BabyAvatarView component

Extract a shared `BabyAvatarView`:

- Inputs: `avatarPath: String?`, `monogram: String`, `size: CGFloat`
- Logic: if `avatarPath` is non-nil, load image and clip to circle; otherwise show monogram text.
- All three locations use this component.

### Refresh mechanism

`HomeHeaderConfig` carries `avatarPath`. Store's `headerConfig` is `@Observable`, so sidebar and top bar update automatically when avatar changes.

## Components to modify

| File | Change |
|------|--------|
| `SidebarMenuView.swift` | Header card triggers `onNavigate(.babyProfile)`, use `BabyAvatarView` |
| `SidebarIndexItem` (in `SidebarDrawer.swift`) | Remove `.profile` case |
| `BabyProfile.swift` | Add `avatarPath: String?` |
| `BabyRepository.swift` | Add `updateAvatar(_:)` with file I/O |
| `BabyProfileView.swift` | Add photo picker (confirmationDialog + PhotosPicker + SystemImagePicker), use `BabyAvatarView` |
| `HomeHeaderConfig` (in `HomeModels.swift`) | Add `avatarPath: String?`, populate in `from(_:)` |
| `MagazineTopBar.swift` | Use `BabyAvatarView` |
| New: `BabyAvatarView.swift` | Shared avatar display component |
