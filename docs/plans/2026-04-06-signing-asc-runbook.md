# 2026-04-06 Signing / ASC / TestFlight Runbook

## Goal

Take the repository from "repo-side release gates are green" to "signed archive uploaded to App Store Connect and ready for TestFlight / review".

This runbook assumes the current repository state:

- App target: `sprout`
- Bundle ID: `zd.sprout`
- Version: `MARKETING_VERSION = 1.0`
- Build number: `CURRENT_PROJECT_VERSION = 1`
- Deployment target: iOS 17.0+
- Shared scheme: `sprout`
- Entitlements file is effectively empty: [sprout.entitlements](/Users/ze/Documents/opc/firstgrowth/sprout/sprout.entitlements)
- Localized display names and camera/photo usage strings already exist

## Current repo-side gates already complete

- Debug build passes
- Full unit test suite passes
- Static analysis passes
- Unsigned Release archive passes
- Simulator install + cold launch smoke passes

## Before touching signing

1. Decide the release version you actually want to ship.
2. Bump:
   - `MARKETING_VERSION`
   - `CURRENT_PROJECT_VERSION`
3. Re-run:
   - `xcodebuild build`
   - `xcodebuild test`
4. Keep the generated archive path from the final Release preflight if you want a last local reference build.

## Step 1: Prepare Apple-side prerequisites

Required external access:

- Apple Developer Program team that owns `zd.sprout`
- App Store Connect access with app creation / TestFlight permissions

Confirm these exist:

- A valid Apple Developer team
- An iOS Distribution certificate available in Xcode
- Automatic signing allowed for the app target, or a manually created provisioning profile if your org requires manual signing
- App Store Connect app record for `zd.sprout`, or permission to create it

## Step 2: Verify Xcode signing setup

In Xcode:

1. Open [sprout.xcodeproj](/Users/ze/Documents/opc/firstgrowth/sprout.xcodeproj).
2. Select target `sprout`.
3. Open `Signing & Capabilities`.
4. Confirm:
   - Team is the intended shipping team
   - Bundle Identifier stays `zd.sprout`
   - `Automatically manage signing` is on, unless your org requires manual provisioning
5. Confirm no unexpected capabilities were re-added.
   - Current repo expectation: no CloudKit, no Push, no background remote notifications
6. Confirm [sprout.entitlements](/Users/ze/Documents/opc/firstgrowth/sprout/sprout.entitlements) remains minimal.

Notes:

- The app target currently uses `DEVELOPMENT_TEAM = B47K832US9`.
- The test target has a different team configured in the project file; that does not block shipping the app, but if you need real-device test execution later, align it.

## Step 3: Verify App Store Connect app record

If the app record does not exist yet:

1. In App Store Connect, create a new iOS app.
2. Use the shipping bundle ID: `zd.sprout`.
3. App name:
   - English display name in-app is `sprout`
   - Chinese display name in-app is `初长`
4. Choose the SKU your team wants to keep permanently.

If the app record already exists:

1. Confirm bundle ID matches `zd.sprout`.
2. Confirm no legacy capability expectations remain from earlier experiments.

## Step 4: Fill required App Store Connect metadata

Prepare these before upload:

- App name
- Subtitle
- Description
- Keywords
- Support URL
- Marketing URL if required by your team
- Privacy Policy URL
- App review contact info
- Copyright
- Age rating questionnaire

Recommended consistency checks:

- Mention bilingual support truthfully
- Do not mention CloudKit, family sharing, notifications, or subscriptions
- Keep positioning aligned with current v1 scope: local-first baby record app

## Step 5: Complete App Privacy and permissions metadata

Current shipped permission copy:

- Camera: used to take photos for records
- Photo library: used to choose photos for records

In App Store Connect privacy answers, align with actual behavior:

- Photo usage is local-first
- No fake cloud backup claim
- No notification data collection claim unless you later add it for real

## Step 6: Prepare screenshots and store assets

Required external assets usually include:

- iPhone screenshots for the display sizes App Store Connect currently requires
- Optional promotional artwork if your team wants it

Recommended screenshot set:

1. Onboarding
2. Home timeline + action bar
3. Growth chart + entry flow
4. Treasure timeline
5. Settings / language screen

Because language switching is retained, generate at least:

- one Chinese screenshot set
- one English verification pass for text overflow and tone

## Step 7: Create a signed archive

In Xcode:

1. Select scheme `sprout`
2. Select `Any iOS Device (arm64)` or generic iOS destination
3. `Product` -> `Archive`

Success criteria:

- Organizer opens with a new archive
- No signing error
- No capability mismatch warning that changes shipping behavior

## Step 8: Validate and upload to App Store Connect

From Organizer:

1. Select the latest `sprout` archive
2. Click `Distribute App`
3. Choose `App Store Connect`
4. Choose `Upload`
5. Keep symbol upload enabled unless your team has a separate crash-symbol pipeline
6. Complete validation
7. Upload

Do not continue if validation reports:

- entitlement mismatch
- bundle ID mismatch
- missing privacy strings
- invalid signing assets

## Step 9: TestFlight release flow

After upload finishes:

1. Wait for processing in App Store Connect
2. Open the uploaded build
3. Confirm:
   - version and build number are correct
   - localized metadata is attached correctly
   - no capability warning appears
4. Add internal testers first
5. Run a final human smoke pass on the processed TestFlight build

Recommended TestFlight smoke:

1. First launch + onboarding
2. Home:
   - milk
   - diaper
   - sleep
   - food
   - undo
3. Growth:
   - metric switch
   - add record
   - tooltip / scrubbing
4. Treasure:
   - create memory
   - weekly letter
   - image failure fallback
5. Settings:
   - language switch
   - baby profile edits
6. Accessibility:
   - Dynamic Type sanity
   - VoiceOver sanity

## Step 10: External testing or App Review submission

For external TestFlight:

1. Complete Beta App Review fields if required
2. Add external tester group
3. Submit build for external review

For App Review:

1. Pick the intended build
2. Attach final metadata
3. Answer export compliance if prompted
4. Submit for review

## Stop / no-go conditions

Do not ship if any of these remain unresolved:

- build / test / analyze / archive red in repo
- signing mismatch or capability drift
- language switch visibly breaks one of the major screens
- startup failure path regressed into destructive recovery
- photo deletion path regressed into deleting outside app-owned storage

## Final minimal external checklist

Once the repo is green, the remaining non-repo work compresses to:

1. Configure signing in Xcode for the shipping team
2. Create or verify the App Store Connect app record
3. Fill metadata + privacy answers + screenshots
4. Archive and upload from Organizer
5. Run final TestFlight human smoke
6. Submit external TestFlight or App Review
