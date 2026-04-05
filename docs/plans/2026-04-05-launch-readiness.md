# Sprout Launch Readiness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bring `sprout` from "promising internal build" to a coherent, safe, publicly shippable v1.

**Architecture:** Ship a smaller but honest v1 first. Prefer removing or hiding unfinished capabilities over shipping fake or misleading UX. Close data-safety, state-correctness, error-handling, and test gaps before feature polish.

**Tech Stack:** SwiftUI, SwiftData, Observation, PhotosUI, UserDefaults, String Catalogs, Xcode unit tests, Xcode UI tests

---

## Locked Product Decisions

- First public build is `local-first`, `single baby`, `free`, and does **not** include CloudKit sync, family sharing, or subscriptions.
- Public v1 must remove `cloud`, `family`, and `paywall` from visible user paths.
- V1 removes notification permission requests and related unfinished notification capability/config.
- V1 ships with bilingual support: `zh-Hans + English`.
- In-app language switching is a real v1 feature and must fully work across the app.
- Growth English title is `Growth`.
- English food tags should be a narrower, ingredient-oriented set and must retain `First taste`.

## Task Status Model

- `todo`: not started
- `in_progress`: currently owned by one agent
- `review`: code complete, waiting for verification
- `blocked`: waiting on product decision or another task
- `done`: merged and verified

## Master Tracker

| ID | Priority | Status | Area | Parallel Group | Depends On |
|----|----------|--------|------|----------------|------------|
| D01 | P0 | done | Product scope | Decisions | - |
| D02 | P0 | done | Language strategy | Decisions | - |
| D03 | P0 | done | Notification strategy | Decisions | - |
| E01 | P0 | todo | Safe app bootstrap | Core Safety | D01 |
| E02 | P0 | todo | Store corruption / migration test | Core Safety | E01 |
| E03 | P0 | todo | Release entitlement cleanup | Config | D01, D03 |
| E04 | P0 | todo | Remove fake settings/paywall UX | Shell Cleanup | D01, D02 |
| E05 | P0 | todo | Baby profile state propagation | Shared State | D01 |
| E06 | P0 | todo | Structured logging + user-visible errors | Reliability | E01 |
| E07 | P0 | todo | Home flow test expansion | Tests-Home | E05, E06 |
| E08 | P0 | todo | Growth flow test expansion | Tests-Growth | E06 |
| E09 | P0 | todo | Treasure flow test expansion | Tests-Treasure | E06 |
| E10 | P0 | todo | Add UI smoke test target | Tests-UI | E04, E05 |
| E11 | P1 | todo | Treasure i18n cleanup | I18N-Treasure | D02 |
| E12 | P1 | todo | Onboarding / default-name i18n cleanup | I18N-Onboarding | D02 |
| E13 | P1 | todo | Real language selection support or hide permanently | I18N-Infra | D02 |
| E14 | P1 | todo | Reminder notifications implementation | Notifications | D03 |
| E15 | P1 | todo | Image normalization and storage hardening | Media | D01 |
| E16 | P1 | todo | Performance and memory smoke pass | Perf | E15 |
| E17 | P1 | todo | Accessibility + dark mode audit | UX QA | E04, E05, E11 |
| E18 | P0 | todo | Release verification pass | Release QA | E01-E10 |
| E19 | P1 | todo | App Store / TestFlight release checklist | Release Ops | E18 |

## Recommended Sub-Agent Bundles

Use fresh sub-agents with disjoint write scopes where possible.

| Bundle | Recommended Tasks | Primary Write Scope |
|--------|-------------------|---------------------|
| A. Core Safety | E01, E02 | `sprout/SproutApp.swift`, new startup error view, bootstrap tests |
| B. Config Cleanup | E03 | `sprout/Info.plist`, `sprout/sprout.entitlements`, `sprout.xcodeproj/project.pbxproj` |
| C. Shell Cleanup | E04 | `sprout/Features/Shell/*` |
| D. Shared State | E05 | `sprout/ContentView.swift`, `sprout/Domain/Baby/*`, `sprout/Features/Shell/*`, possibly new profile state object |
| E. Reliability | E06 | `sprout/Features/Home/HomeStore.swift`, `sprout/Features/Growth/GrowthStore.swift`, `sprout/Features/Treasure/TreasureStore.swift`, shared logging helper |
| F. Home Tests | E07 | `sproutTests/*Home*`, `sproutTests/*Record*`, `sproutTests/TestSupport.swift` |
| G. Growth Tests | E08 | new `sproutTests/*Growth*` files |
| H. Treasure Tests | E09 | new `sproutTests/*Treasure*` files |
| I. UI Tests | E10 | new `sproutUITests/*`, `sprout.xcodeproj/project.pbxproj`, scheme updates |
| J. Treasure i18n | E11 | `sprout/Domain/Treasure/*`, `sprout/Features/Treasure/*`, string catalog |
| K. Onboarding i18n | E12 | `sprout/Features/Onboarding/*`, `sprout/Domain/Baby/BabyProfile.swift`, string catalog |
| L. Language Infra | E13 | `sprout/Shared/*`, `sprout/Features/Shell/LanguageRegionView.swift`, app root injection |
| M. Notifications | E14 | onboarding files, new reminder scheduler/service, tests |
| N. Media | E15, E16 | photo storage files, food/treasure compose sheets |

## Decision Tasks

### D01: Lock first-public release scope

**Owner:** Product / tech lead

**Decision made:**

- First public build includes only:
  - record
  - growth
  - treasure
  - onboarding
  - local persistence
- Explicitly exclude:
  - CloudKit sync
  - family sharing
  - subscriptions / paywall
- Remove from public UI:
  - `family`
  - `cloud`
  - `pro/paywall`

**Output required:**

- One short written decision note in issue/PRD/comments
- Mark `family`, `cloud`, `pro/paywall` as either `remove from v1 UI` or `implement now`

**Done when:**

- The engineering team can treat unfinished features as removable without reopening product debate.

### D02: Lock language strategy for v1

**Owner:** Product / tech lead

**Decision made:**

- Choose:
  - `Option B:` fully support `en + zh-Hans` with a working in-app switcher
- Additional locked details:
  - Growth English title: `Growth`
  - English food tags: use a narrower, ingredient-oriented set
  - Keep `First taste`

**Done when:**

- Engineering knows E11-E13 are required before launch and cannot be reduced to "hide language entry".

### D03: Lock notification strategy for v1

**Owner:** Product / tech lead

**Decision made:**

- Choose:
  - `Option A:` remove notification permission request and related entitlements from v1

**Done when:**

- Engineering knows to remove notification-related config rather than finish the feature.

## Engineering Tasks

### E01: Replace destructive bootstrap recovery with safe failure handling

**Priority:** P0

**Parallel Group:** Core Safety

**Files:**

- Modify: `sprout/SproutApp.swift`
- Create: `sprout/Features/Shell/AppStartupErrorView.swift`
- Test: new bootstrap test file if feasible

**Problem:**

- `SproutApp` currently deletes the persistent store if `ModelContainer` creation fails.
- This is unacceptable for a local-first baby record app because corruption or schema issues can silently destroy user data.

**Steps:**

1. Remove the `clearPersistentStoreFiles()` fallback path as the default recovery behavior.
2. Introduce a startup state model:
   - success: app loads normally
   - failure: app shows a blocking error screen
3. Show a calm, non-destructive startup error UI with:
   - a plain-language explanation
   - app restart suggestion
   - optional "contact support / export diagnostics later" placeholder
4. Add structured logging of the underlying bootstrap error.
5. Make sure tests still bypass the real app shell safely.

**Done when:**

- No code path deletes the user store automatically on startup failure.
- A startup persistence failure leads to a user-visible blocking screen, not silent data loss.

### E02: Add store corruption / migration regression coverage

**Priority:** P0

**Parallel Group:** Core Safety

**Depends On:** E01

**Files:**

- Test: new `sproutTests` bootstrap/persistence tests
- Modify: `sprout/SproutApp.swift` as needed for testability

**Steps:**

1. Extract the app bootstrap logic enough to be unit-testable.
2. Add tests for:
   - successful container creation
   - container creation failure surfaces an error state
   - tests still route to `TestHostView`
3. If real corruption simulation is difficult, inject a failing container factory and test state transitions.

**Done when:**

- Bootstrap error behavior is covered by automated tests.

### E03: Clean release entitlements and background modes

**Priority:** P0

**Parallel Group:** Config

**Depends On:** D01, D03

**Files:**

- Modify: `sprout/Info.plist`
- Modify: `sprout/sprout.entitlements`
- Modify: `sprout.xcodeproj/project.pbxproj`

**Problem:**

- The app currently advertises push/background/cloud capabilities that are not implemented in the codebase.

**Steps:**

1. If notifications are out of v1:
   - remove `remote-notification` background mode
   - remove APNs entitlements
2. If CloudKit is out of v1:
   - remove `CloudKit` service entitlement
   - remove empty iCloud container configuration
3. Re-check permission strings and keep only those required by shipping features.
4. Verify resulting signing/config remains valid for Debug and Release.

**Done when:**

- The app binary requests only the capabilities that actually ship in v1.

### E04: Remove or hide fake settings / paywall functionality

**Priority:** P0

**Parallel Group:** Shell Cleanup

**Depends On:** D01, D02

**Files:**

- Modify: `sprout/Features/Shell/SidebarDrawer.swift`
- Modify: `sprout/Features/Shell/SidebarMenuView.swift`
- Modify: `sprout/Features/Shell/PaywallSheet.swift`
- Modify: `sprout/Features/Shell/LanguageRegionView.swift`
- Modify: `sprout/Localization/Localizable.xcstrings`
- Test: `sproutTests/SidebarRoutingTests.swift`

**Recommended path:**

- Hide `family` and `cloud` entries entirely from the v1 sidebar.
- Remove paywall sheet from the public path.
- Keep the language settings page, but convert it from placeholder UI into a real, working in-app language switcher.

**Steps:**

1. Update `SidebarIndexItem.items` so only working routes remain visible.
2. Remove dead-end pro flow wiring.
3. Simplify sidebar tests to match the public v1 information architecture.
4. Audit string catalog keys and delete unused paywall copy if removed.

**Done when:**

- Every visible settings item leads to a real, working user outcome.
- No public path ends in a "coming soon" placeholder for a core v1 setting.

### E05: Make baby profile edits propagate through the entire app shell

**Priority:** P0

**Parallel Group:** Shared State

**Depends On:** D01

**Files:**

- Modify: `sprout/ContentView.swift`
- Modify: `sprout/Domain/Baby/BabyRepository.swift`
- Modify: `sprout/Features/Shell/BabyProfileView.swift`
- Modify: `sprout/Features/Shell/AppShellView.swift`
- Modify: `sprout/Features/Home/HomeModels.swift`
- Modify: `sprout/Features/Home/Components/EmotionHeaderBlock.swift` if needed
- Modify: `sprout/Features/Shell/SidebarMenuView.swift`
- Test: add new state propagation tests

**Problem:**

- Baby name and birthday are loaded once at startup into `HomeHeaderConfig`.
- Editing profile data later does not appear wired to refresh Home, Growth, Treasure, and sidebar state.

**Steps:**

1. Choose a single app-level source of truth for active baby profile:
   - recommended: an `@Observable` app profile state injected into shell and stores
2. Update app bootstrap to populate this source of truth once.
3. Make `BabyProfileView` edit the shared state and persist through repository.
4. Ensure Home/Growth/Treasure stores react to profile changes.
5. Verify name/birthdate changes update:
   - top bar avatar monogram
   - sidebar header
   - home age/day display
   - growth age calculations
   - treasure age calculations for new entries

**Done when:**

- Editing baby profile immediately updates the visible shell and derived feature state without app relaunch.

### E06: Add structured logging and user-visible failure feedback

**Priority:** P0

**Parallel Group:** Reliability

**Depends On:** E01

**Files:**

- Create: `sprout/Shared/AppLogger.swift` or similar
- Modify: `sprout/Features/Home/HomeStore.swift`
- Modify: `sprout/Features/Growth/GrowthStore.swift`
- Modify: `sprout/Features/Treasure/TreasureStore.swift`
- Modify: affected views to show recoverable errors
- Modify: `sprout/Localization/Localizable.xcstrings`

**Problem:**

- Many error paths still only call `assertionFailure`, which disappears in production.

**Steps:**

1. Introduce a lightweight logging helper using `Logger` / `OSLog`.
2. Replace raw `assertionFailure` calls in stores with:
   - log
   - store error state update
   - user-visible feedback where the action failed
3. Add recoverable UX for:
   - save failure
   - load failure
   - image import failure
   - undo failure
4. Keep copy calm and non-alarming, aligned with product tone.

**Done when:**

- All user-triggered save/load failures either show a clear in-app message or an error state.
- Failure details are logged for diagnostics.

### E07: Expand automated coverage for Home flows

**Priority:** P0

**Parallel Group:** Tests-Home

**Depends On:** E05, E06

**Files:**

- Create: `sproutTests/RecordRepositoryTests.swift`
- Create: `sproutTests/RecordValidatorTests.swift`
- Create: `sproutTests/HomeStoreTests.swift`
- Create: `sproutTests/TimelineContentFormatterTests.swift`
- Modify: `sproutTests/TestSupport.swift`

**Coverage target:**

- create milk / diaper / sleep / food records
- invalid record rejection
- ongoing sleep restore / finish
- undo for all home record types
- first-taste hint behavior
- image-path fallback behavior
- profile update impact on header config if shared state is introduced

**Done when:**

- Core home logic has real regression coverage and no longer relies mainly on manual testing.

### E08: Expand automated coverage for Growth flows

**Priority:** P0

**Parallel Group:** Tests-Growth

**Depends On:** E06

**Files:**

- Create: `sproutTests/GrowthFormatterTests.swift`
- Create: `sproutTests/GrowthStoreTests.swift`
- Modify: `sproutTests/TestSupport.swift`

**Coverage target:**

- metric switching persistence
- create / undo height record
- create / undo weight record
- manual input parsing for locale decimal separators
- chart tooltip / selection behavior
- empty/error state rendering data
- AI content generation guardrails for first record / unchanged / increased / decreased

**Done when:**

- Growth module critical flows and formatter logic are covered by unit tests.

### E09: Expand automated coverage for Treasure flows

**Priority:** P0

**Parallel Group:** Tests-Treasure

**Depends On:** E06

**Files:**

- Create: `sproutTests/TreasureStoreTests.swift`
- Create: `sproutTests/WeeklyLetterComposerTests.swift`
- Create: `sproutTests/TreasureRepositoryTests.swift`
- Modify: `sproutTests/TestSupport.swift`

**Coverage target:**

- create memory entry with text only
- create memory entry with images
- discard draft cleanup
- undo memory entry
- weekly letter sync for create / update / delete
- month scrubber hint and visibility state
- image overflow trimming behavior

**Done when:**

- Treasure compose and weekly letter logic have regression coverage.

### E10: Add UI smoke tests for top-level launch flows

**Priority:** P0

**Parallel Group:** Tests-UI

**Depends On:** E04, E05

**Files:**

- Create new `sproutUITests` target
- Modify: `sprout.xcodeproj/project.pbxproj`
- Modify: `sprout.xcodeproj/xcshareddata/xcschemes/sprout.xcscheme`
- Create UI smoke test files

**Minimum UI smoke coverage:**

- cold launch onboarding
- home load
- log milk
- log diaper
- start sleep / finish sleep
- open treasure compose and dismiss safely
- open growth and create one record
- open profile/settings entry

**Done when:**

- There is an executable simulator smoke suite covering the public happy path.

### E11: Finish Treasure module i18n cleanup

**Priority:** P1

**Parallel Group:** I18N-Treasure

**Depends On:** D02

**Files:**

- Modify: `sprout/Features/Treasure/Sheets/TreasureComposeModal.swift`
- Modify: `sprout/Features/Treasure/Components/*`
- Modify: `sprout/Features/Treasure/Cards/*`
- Modify: `sprout/Domain/Treasure/WeeklyLetterComposer.swift`
- Modify: `sprout/Domain/Treasure/TreasureMonthAnchorBuilder.swift`
- Modify: `sprout/Localization/Localizable.xcstrings`

**Problem:**

- Treasure still contains many hardcoded Chinese strings and persists weekly letters as final rendered text.

**Steps:**

1. Remove hardcoded UI copy from compose modal and cards.
2. Replace month label formatting with locale-aware rendering.
3. Because bilingual ships in v1, decide whether weekly letters remain "generated once and frozen" or move to locale-neutral facts:
   - recommended: refactor toward facts + render-time templates
4. Add tests for both languages if bilingual support is in scope.

**Done when:**

- Treasure UI no longer depends on hardcoded Chinese strings.
- Weekly letter behavior is consistent with chosen bilingual strategy.

### E12: Finish onboarding and default-name i18n cleanup

**Priority:** P1

**Parallel Group:** I18N-Onboarding

**Depends On:** D02

**Files:**

- Modify: `sprout/Features/Onboarding/OnboardingModels.swift`
- Modify: `sprout/Features/Onboarding/OnboardingStepViews.swift`
- Modify: `sprout/Domain/Baby/BabyProfile.swift`
- Modify: `sprout/Localization/Localizable.xcstrings`
- Modify tests that depend on `"宝宝"`

**Problem:**

- Onboarding migration logic and default baby name are tied to a Chinese literal.

**Steps:**

1. Replace `"宝宝"` sentinel logic with a locale-neutral bootstrap marker or explicit `hasCustomizedProfile` signal.
2. Localize the default display name safely.
3. Update migration tests to avoid language-specific assumptions.

**Done when:**

- Onboarding migration does not rely on one Chinese string to infer user state.

### E13: Implement real language selection support

**Priority:** P1

**Parallel Group:** I18N-Infra

**Depends On:** D02

**Files:**

- Modify: `sprout/Shared/AppLanguage.swift`
- Modify: `sprout/Shared/LocalizationService.swift`
- Modify: app root injection points
- Modify: `sprout/Features/Shell/LanguageRegionView.swift`
- Modify tests as needed

1. Add persistent app-language storage.
2. Inject selected language into `LocalizationService`.
3. Re-render app root on language change.
4. Verify string catalog and formatter behavior across launch and feature flows.
5. Implement the locked English content decisions:
   - Growth title uses `Growth`
   - food tags become a narrower ingredient-oriented set
   - preserve `First taste`

**Done when:**

- The language page truly changes app language across the app.

### E14: Remove notification permission request and related unfinished notification wiring

**Priority:** P0

**Parallel Group:** Notifications Cleanup

**Depends On:** D03

**Files:**

- Modify: `sprout/Features/Onboarding/OnboardingStepViews.swift`
- Modify: settings UI if notification copy/entry exists
- Modify: `sprout/Info.plist`
- Modify: `sprout/sprout.entitlements`
- Add tests where feasible

**Steps:**

1. Remove notification permission request from onboarding.
2. Remove or neutralize any notification-related copy in settings/onboarding.
3. Clean up unused background/push capability declarations that remain after E03.
4. Add regression coverage so onboarding no longer triggers notification auth in v1.

**Done when:**

- Notification permission is never requested anywhere in public v1.

### E15: Harden image import, storage, and file lifecycle

**Priority:** P1

**Parallel Group:** Media

**Depends On:** D01

**Files:**

- Modify: `sprout/Domain/Records/FoodPhotoStorage.swift`
- Modify: `sprout/Domain/Treasure/TreasurePhotoStorage.swift`
- Modify: `sprout/Features/Home/Sheets/FoodRecordSheet.swift`
- Modify: `sprout/Features/Treasure/Sheets/TreasureComposeModal.swift`
- Add tests around file cleanup where feasible

**Problem:**

- Imported image data is stored directly with no normalized resize/compression pipeline beyond JPEG conversion in some paths.

**Steps:**

1. Normalize imported/captured images to bounded dimensions before persistence.
2. Standardize JPEG compression and orientation handling.
3. Ensure temporary or replaced images are always cleaned up.
4. Verify fallback behavior when image files go missing.

**Done when:**

- Image import has bounded disk and memory behavior and predictable cleanup.

### E16: Run a focused performance and memory hardening pass

**Priority:** P1

**Parallel Group:** Perf

**Depends On:** E15

**Files:**

- Modify only if profiling reveals issues in:
  - `FoodPhotoCard`
  - `TreasureMemoryCard`
  - `TreasureComposeModal`
  - chart components

**Steps:**

1. Measure cold launch, home scroll, treasure image rendering, and growth chart interaction.
2. Watch for large image decode spikes and repeated `UIImage(contentsOfFile:)` work.
3. Introduce only the smallest fixes needed:
   - cached thumbnails
   - smaller preview images
   - reduced repeated loads

**Done when:**

- No obvious memory spikes or jank in normal photo-heavy usage.

### E17: Complete accessibility and dark mode audit

**Priority:** P1

**Parallel Group:** UX QA

**Depends On:** E04, E05, E11

**Files:**

- Touch only affected view files after audit

**Audit checklist:**

- dynamic type sanity
- VoiceOver labels on all tappable controls
- contrast in dark mode
- touch target sizes
- sheet dismiss affordances
- image delete button accessibility

**Done when:**

- Public launch flows are usable in dark mode and have reasonable accessibility coverage.

### E18: Execute release verification pass

**Priority:** P0

**Parallel Group:** Release QA

**Depends On:** E01-E10

**Files:**

- No required code changes; create checklist doc if useful

**Verification commands:**

```bash
xcodebuild clean build -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Manual smoke checklist:**

1. Fresh install shows onboarding
2. Existing user migration skips onboarding
3. Home logging works for all four primary actions
4. Undo works
5. Growth create / undo works
6. Treasure create / undo works
7. Profile edits propagate live
8. No dead-end settings item remains
9. Dark mode works
10. App relaunch preserves data

**Done when:**

- Build, tests, and manual smoke checks all pass on a clean simulator.

### E19: Prepare TestFlight / App Store release package

**Priority:** P1

**Parallel Group:** Release Ops

**Depends On:** E18

**Owner:** Engineering + product

**Tasks:**

1. Confirm bundle ID, signing, and Release build settings.
2. Prepare screenshots for supported device classes.
3. Review permission copy for camera/photo access.
4. Confirm privacy answers match actual shipped capabilities.
5. Draft TestFlight release notes.
6. Create rollback plan for first public build.

**Done when:**

- The project is not only code-complete but operationally ready to distribute.

## Suggested Execution Waves

### Wave 0: Decisions

- D01
- D02
- D03

### Wave 1: Must-fix launch blockers

- E01
- E03
- E04
- E05

### Wave 2: Reliability and test backbone

- E02
- E06
- E07
- E08
- E09
- E10

### Wave 3: Scope-dependent follow-up

- E11
- E12
- E13
- E14
- E15
- E16
- E17

### Wave 4: Final launch gate

- E18
- E19

## Progress Tracking Template

Use this block in the main issue or thread:

```markdown
## Launch Readiness Tracker

- [ ] D01 Lock first-public release scope
- [ ] D02 Lock language strategy
- [ ] D03 Lock notification strategy
- [ ] E01 Safe bootstrap recovery
- [ ] E02 Bootstrap regression coverage
- [ ] E03 Entitlement and background-mode cleanup
- [ ] E04 Remove fake settings / paywall UX
- [ ] E05 Baby profile state propagation
- [ ] E06 Structured logging + user-visible errors
- [ ] E07 Home tests
- [ ] E08 Growth tests
- [ ] E09 Treasure tests
- [ ] E10 UI smoke tests
- [ ] E11 Treasure i18n cleanup
- [ ] E12 Onboarding i18n cleanup
- [ ] E13 Real language switcher or remove it
- [ ] E14 Remove notification permission request
- [ ] E15 Image storage hardening
- [ ] E16 Performance hardening
- [ ] E17 Accessibility + dark mode audit
- [ ] E18 Release verification pass
- [ ] E19 TestFlight / App Store release package
```

## Notes for Agent Dispatch

- Do not start E03, E04, E11, E12, E13, or E14 until D01-D03 are explicitly resolved.
- Prefer one bundle per sub-agent and keep write scopes disjoint.
- Land E01 before any other persistence-heavy refactors.
- Land E04 before UI smoke tests, otherwise tests will encode dead-end UX that should be removed.
- Land E05 before deep feature testing, otherwise many tests will lock in stale header behavior.
