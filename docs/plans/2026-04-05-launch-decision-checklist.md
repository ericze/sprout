# Sprout V1 Launch Decision Checklist

**Purpose:** Resolve the minimum product decisions that block launch-readiness engineering work.

**How to use this document:**

- Fill in the decision for each item.
- Keep the chosen option and delete the rejected options if you want a cleaner version.
- Once all three decisions are final, engineering can start parallel execution without reopening product scope.

---

## Summary Recommendation

For the fastest, lowest-risk first public release, use this default package:

- `local-first`
- `single baby`
- `free`
- `no CloudKit sync in v1`
- `no family sharing in v1`
- `no in-app language switcher in v1`
- `follow system language only`
- `no notification permission request in v1` unless reminders are fully implemented now

This is the smallest scope that matches the current codebase and avoids shipping fake settings or misleading capability prompts.

---

## D01: First Public Release Scope

**Why this needs a decision**

The current app shell exposes unfinished `family`, `cloud`, and `pro/paywall` paths. Engineering needs explicit permission to remove or hide them for v1 instead of preserving placeholder UX.

**Recommended option**

- `Option A (recommended):` V1 ships only:
  - record
  - growth
  - treasure
  - onboarding
  - local persistence
  - baby profile/settings needed by these features

**Alternative options**

- `Option B:` include CloudKit sync in v1
- `Option C:` include family sharing in v1
- `Option D:` include subscriptions / paywall in v1

**Current engineering reality**

- CloudKit entitlement exists, but no real CloudKit sync implementation is wired.
- Family and paywall are UI placeholders, not complete user journeys.
- Keeping these visible adds review, QA, and UX risk without delivering user value.

**Decision**

- Selected option: `________________`
- Final v1 excludes: `________________`
- Visible sidebar/settings items allowed in v1: `________________`

**Engineering consequence**

- If you choose Option A, engineering will:
  - remove or hide `family`
  - remove or hide `cloud`
  - remove paywall sheet from the public path

**Done when**

- Product explicitly confirms whether these unfinished capabilities are removed from public v1.

---

## D02: Language Strategy

**Why this needs a decision**

The app has partial bilingual infrastructure, but the current in-app language page does not actually switch app language. Treasure and onboarding still have language-coupled behavior in several places.

**Recommended option**

- `Option A (recommended):` No in-app language switcher for first public release. App follows system language only.

**Alternative options**

- `Option B:` Ship full `English + zh-Hans` support with a working in-app language switcher.

**Current engineering reality**

- String catalog and localization helpers are present.
- The language settings page currently changes only local UI state and shows a restart alert; it does not reconfigure the app.
- Some Treasure and onboarding paths still depend on hardcoded Chinese strings or Chinese-default assumptions.

**Open language details already identified**

- Growth AI card English title:
  - keep explicit `AI`
  - or weaken the label toward a calmer descriptive title
- Food suggestion tags in English:
  - direct translation of current set
  - or narrower ingredient-first set
  - decide whether to keep `First taste`

**Decision**

- Selected option: `________________`
- If Option B, release languages are: `________________`
- Growth AI English title decision: `________________`
- English food tag strategy: `________________`

**Engineering consequence**

- If you choose Option A, engineering will:
  - remove or neutralize the in-app language selector
  - keep system-language behavior only
- If you choose Option B, engineering will:
  - complete app-wide language switching
  - finish Treasure / onboarding language cleanup before launch

**Done when**

- Product confirms whether language switching is a real v1 feature or not.

---

## D03: Notification Strategy

**Why this needs a decision**

Onboarding currently asks for notification permission, but there is no finished reminder feature in the codebase. The project also still advertises background/push-related capabilities in config.

**Recommended option**

- `Option A (recommended):` Remove notification permission request from v1. Do not request notification access until reminders are real.

**Alternative options**

- `Option B:` Implement a real reminder feature now and keep notification permission in onboarding/settings.

**Minimum acceptable definition if Option B is selected**

- User grants permission
- App schedules a gentle local reminder after low or missing logging activity
- Reminder is cancelled/rescheduled when the user records activity
- User-facing copy matches actual behavior

**Current engineering reality**

- Notification authorization is requested in onboarding.
- No completed reminder scheduling flow is visible in the codebase.
- This creates a poor trust signal in a quiet, low-anxiety product.

**Decision**

- Selected option: `________________`
- If Option B, reminder trigger rule is: `________________`
- If Option B, reminder entry point/settings location is: `________________`

**Engineering consequence**

- If you choose Option A, engineering will:
  - remove notification permission request from onboarding
  - clean related entitlements/background config
- If you choose Option B, engineering will:
  - implement reminder scheduling
  - add tests
  - expose a real user control path

**Done when**

- Product confirms whether notifications are absent from v1 or fully implemented.

---

## Decision Snapshot

Fill this section after all three are decided.

```markdown
## Sprout V1 Decision Snapshot

- Scope: [local-first only / includes X / excludes Y]
- Language: [system language only / bilingual with in-app switcher]
- Notifications: [removed for v1 / implemented as gentle reminders]
```

This snapshot should be copied into the launch-readiness tracker issue or PR description.

---

## Recommended Final Answer If You Want Me To Assume Defaults

If you want engineering to proceed immediately with the lowest-risk assumptions, use:

- Scope: `local-first only`, remove `cloud`, `family`, and `paywall` from public v1
- Language: `follow system language only`, no in-app language switcher in v1
- Notifications: `remove notification permission request` from v1
