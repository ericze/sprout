# Auth + Supabase Backend + Cloud Sync (Phase 2 of Family Group Pro)

**Date**: 2026-04-09
**Release**: 1.1.0
**Status**: Ready for Implementation
**Phase**: 2 of 4 (StoreKit -> Auth/Backend -> Multi-Baby/Family -> AI)
**Depends on**: Phase 1 (StoreKit + Paywall) - COMPLETE
**Revision Note**: This revision replaces the original draft with an implementable plan that matches the current SwiftData codebase and avoids device-clock conflicts, client-only paywall assumptions, and delete-flow regressions.

## Background

Phase 1 established StoreKit 2 subscription infrastructure with `SubscriptionManager` and `PaywallView`. The app already defines `Entitlement.cloudSync`, but Phase 1 does not have any server-trusted entitlement model.

The current app is fully local-first:
- `RecordItem`, `MemoryEntry`, and `BabyProfile` live only in SwiftData.
- Food photos, treasure photos, and baby avatars are stored on-device.
- The delete flow assumes local rows disappear immediately and can be restored during a 4-second undo window.
- `MemoryEntry` already supports multiple photos per entry.
- `BabyProfile` does not yet have an explicit stable UUID field.

Phase 2 adds:
- Supabase Auth for account identity
- Supabase Postgres for cloud metadata sync
- Supabase Storage for image backup
- Multi-device access for one account

This phase does **not** add family sharing yet. The data model must, however, stop blocking Phase 3.

## Non-Negotiable Decisions

| Topic | Decision |
|------|----------|
| Authentication | Email + password via Supabase Auth |
| Backend | Supabase Auth + Postgres + Storage |
| Availability | Cloud Sync is available to any authenticated user in Phase 2 |
| Paywall | No sync paywall enforcement in Phase 2; server-backed entitlement enforcement is deferred |
| Sync trigger | Automatic sync with 5-second debounce plus manual "Sync Now" |
| Conflict model | Server-ordered LWW using optimistic concurrency (`version`), never device-clock comparison |
| Incremental pull | Per-table cursor using server `updated_at` with an upper-bound snapshot |
| Delete model | Immediate local delete + separate tombstone queue for remote delete |
| Image metadata | Store storage paths, not public URLs |
| Memory photos | Preserve multi-image support |
| Local account model | One local database is bound to one authenticated user; account switching is out of scope |
| Data scope | `RecordItem` + `MemoryEntry` + `BabyProfile`; `WeeklyLetter` stays local and is recomputed |

## Why This Revision Changes the Original Draft

The original draft had six implementation blockers:
- It depended on `profiles` rows that were never guaranteed to exist.
- It compared device timestamps with server timestamps for conflict resolution.
- It changed deletion semantics in a way that would have broken current fetch paths and undo behavior.
- It introduced remote `baby_id` without adding a matching local field.
- It regressed `MemoryEntry` from multiple photos to one photo.
- It treated Cloud Sync as Pro-only in UI while leaving server access open to any authenticated user.

This revision removes those blockers instead of trying to patch around them.

## Scope Boundaries

### In Scope
- Supabase project setup
- Email + password authentication
- Session restore on app launch
- Single-account local binding
- Sync for `BabyProfile`, `RecordItem`, and `MemoryEntry`
- Remote image backup for food photos, treasure photos, and baby avatars
- Multi-device sync for the same authenticated account
- Local migration/bootstrap for legacy data
- Account UI and Cloud Sync UI
- Unit tests and Supabase integration tests

### Out of Scope
- Family group sharing and invitations
- Multi-account switching on the same local database
- Sign in with Apple
- Real-time subscriptions
- Server-backed paid entitlement enforcement
- Server-side receipt validation
- WeeklyLetter sync
- Analytics
- Export/import
- Manual conflict resolution UI

## Account Binding Model

This must be explicit before implementation starts.

Phase 2 supports **one authenticated account per local SwiftData store**.

Rules:
1. On first successful authentication, if the local store is not yet linked, store `linkedUserID` locally.
2. All future sessions on this device must match `linkedUserID`.
3. If a different Supabase account attempts to sign in while local data is linked to another user, block the sign-in and show a destructive "Reset local data before switching account" path.
4. Signing out only ends the remote session. It does not erase local data.

Reasoning:
- The current SwiftData store is not partitioned by user.
- Without an explicit binding rule, cross-account sign-in would mix two families' local data.
- A safe account switch flow can be added later, but it is not required for this phase.

## Supabase Database Schema

### Tables

### `profiles`

`profiles` must be created automatically from `auth.users`. The client must not rely on a race-prone manual bootstrap.

```sql
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `baby_profiles`

```sql
CREATE TABLE public.baby_profiles (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT '宝宝',
  birth_date TIMESTAMPTZ NOT NULL,
  gender TEXT,
  avatar_storage_path TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  has_completed_onboarding BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  version BIGINT NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_baby_profiles_user_id ON public.baby_profiles(user_id);
CREATE INDEX idx_baby_profiles_updated_at ON public.baby_profiles(updated_at);
```

### `record_items`

```sql
CREATE TABLE public.record_items (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  baby_id UUID NOT NULL REFERENCES public.baby_profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  value DOUBLE PRECISION,
  left_nursing_seconds INTEGER NOT NULL DEFAULT 0,
  right_nursing_seconds INTEGER NOT NULL DEFAULT 0,
  sub_type TEXT,
  image_storage_path TEXT,
  ai_summary TEXT,
  tags JSONB,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  version BIGINT NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_record_items_user_id ON public.record_items(user_id);
CREATE INDEX idx_record_items_baby_id ON public.record_items(baby_id);
CREATE INDEX idx_record_items_timestamp ON public.record_items(timestamp DESC);
CREATE INDEX idx_record_items_updated_at ON public.record_items(updated_at);
```

### `memory_entries`

`MemoryEntry` must preserve ordered multi-image support.

```sql
CREATE TABLE public.memory_entries (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  baby_id UUID NOT NULL REFERENCES public.baby_profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL,
  age_in_days INTEGER,
  image_storage_paths JSONB NOT NULL DEFAULT '[]'::jsonb,
  note TEXT,
  is_milestone BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  version BIGINT NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_memory_entries_user_id ON public.memory_entries(user_id);
CREATE INDEX idx_memory_entries_baby_id ON public.memory_entries(baby_id);
CREATE INDEX idx_memory_entries_updated_at ON public.memory_entries(updated_at);
```

### Triggers and Functions

### Auto-create `profiles` rows

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, COALESCE(NEW.email, ''))
  ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### Keep `updated_at` and `version` server-authored

```sql
CREATE OR REPLACE FUNCTION public.set_row_sync_metadata()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();

  IF TG_OP = 'INSERT' THEN
    NEW.created_at = COALESCE(NEW.created_at, now());
    NEW.version = COALESCE(NEW.version, 1);
  ELSE
    NEW.version = OLD.version + 1;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER set_baby_profiles_sync_metadata
BEFORE INSERT OR UPDATE ON public.baby_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_row_sync_metadata();

CREATE TRIGGER set_record_items_sync_metadata
BEFORE INSERT OR UPDATE ON public.record_items
FOR EACH ROW EXECUTE FUNCTION public.set_row_sync_metadata();

CREATE TRIGGER set_memory_entries_sync_metadata
BEFORE INSERT OR UPDATE ON public.memory_entries
FOR EACH ROW EXECUTE FUNCTION public.set_row_sync_metadata();
```

`updated_at` is used only as a **server cursor** for incremental pull.
`version` is used only for **optimistic concurrency** on push.
The client must not compare `updated_at` with a device-authored timestamp.

### Fetch server time for pull upper bounds

```sql
CREATE OR REPLACE FUNCTION public.server_now()
RETURNS TIMESTAMPTZ
LANGUAGE sql
STABLE
AS $$
  SELECT now();
$$;
```

`SyncEngine.fetchServerNow()` should call this RPC instead of trusting device time.

### Row Level Security (RLS)

```sql
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.baby_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.record_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own profile"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Users update own profile"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY "Users manage own baby_profiles"
  ON public.baby_profiles FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users manage own record_items"
  ON public.record_items FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users manage own memory_entries"
  ON public.memory_entries FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

### Storage Buckets

| Bucket | Path | Purpose |
|------|------|---------|
| `food-photos` | `{userId}/{recordId}.jpg` | Food record photo |
| `treasure-photos` | `{userId}/{memoryId}/{assetId}.jpg` | Memory entry photos |
| `baby-avatars` | `{userId}/{babyId}.jpg` | Baby avatar |

Phase 2 stores **paths**, not public URLs, in Postgres.
The app downloads files into local cache folders and continues to render from local disk.

## Local SwiftData Changes

### Migration Strategy

Do **not** assume a lightweight migration is enough.

Reason:
- `BabyProfile` needs a new stable `id`.
- `RecordItem` and `MemoryEntry` need a new required `babyID`.
- Legacy local data must be backfilled before any sync starts.

Use an explicit SwiftData `SchemaMigrationPlan` plus a one-time `LocalSyncBootstrapper`.

### Bootstrap responsibilities

Run `LocalSyncBootstrapper` once before any sync is allowed:
1. Ensure there is exactly one active `BabyProfile`. Reuse current `BabyRepository.createDefaultIfNeeded()` behavior if needed.
2. Assign a UUID to every legacy `BabyProfile` that does not have one yet.
3. Backfill `babyID` on all existing `RecordItem` rows with the active baby's UUID.
4. Backfill `babyID` on all existing `MemoryEntry` rows with the active baby's UUID.
5. Set all syncable rows to `syncState = .pendingUpsert` and `remoteVersion = nil`.
6. Leave `WeeklyLetter` untouched.

This makes existing local data uploadable on the first authenticated sync.

### SyncState

```swift
enum SyncState: String, Codable {
    case synced
    case pendingUpsert
}
```

There is intentionally no `pendingDelete` state on the primary models.
Deletes use a separate tombstone queue so current UI fetches do not need to start filtering soft-deleted local rows.

### New Local Metadata Models

### `SyncDeletionTombstone`

```swift
@Model
final class SyncDeletionTombstone {
    @Attribute(.unique) var id: UUID
    var entityType: String            // babyProfile / recordItem / memoryEntry
    var entityID: UUID
    var remoteVersion: Int64?
    var readyAfter: Date
    var storagePathsPayload: String?  // encoded [String] for remote asset cleanup

    init(
        id: UUID = UUID(),
        entityType: String,
        entityID: UUID,
        remoteVersion: Int64?,
        readyAfter: Date,
        storagePathsPayload: String? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.entityID = entityID
        self.remoteVersion = remoteVersion
        self.readyAfter = readyAfter
        self.storagePathsPayload = storagePathsPayload
    }
}
```

### `SyncCursorStore`

Persist one cursor set per linked user:

```swift
struct SyncCursor: Codable {
    var babyProfilesAt: Date?
    var recordItemsAt: Date?
    var memoryEntriesAt: Date?
}
```

This can live in `UserDefaults` keyed by `linkedUserID`.
It does not need to be a SwiftData model.

### Model Extensions

### `BabyProfile`

```swift
@Attribute(.unique) var id: UUID
var avatarPath: String?
var remoteAvatarPath: String?
var remoteVersion: Int64?
var syncStateRaw: String = SyncState.pendingUpsert.rawValue
```

### `RecordItem`

```swift
var babyID: UUID
var imageURL: String?          // existing local file path, kept as-is in Phase 2
var remoteImagePath: String?
var remoteVersion: Int64?
var syncStateRaw: String = SyncState.pendingUpsert.rawValue
```

### `MemoryEntry`

```swift
var babyID: UUID
var imageLocalPath: String?            // existing encoded local paths, kept as-is
var remoteImagePathsPayload: String?   // encoded [String]
var remoteVersion: Int64?
var syncStateRaw: String = SyncState.pendingUpsert.rawValue
```

### Important Notes

- `serverId` is not needed. Local UUIDs are the remote primary keys.
- `remoteVersion` is authoritative for push concurrency.
- `syncStateRaw` is stored as raw string to stay SwiftData-friendly.
- Each model should expose a computed `syncState: SyncState` wrapper around `syncStateRaw`.
- Existing confusing field names such as `RecordItem.imageURL` are not renamed in Phase 2. Keep the diff small and introduce remote path fields separately.

## Repository Layer Changes

All create and update operations must mark rows as dirty:

```swift
model.syncState = .pendingUpsert
```

If the row was previously synced, keep `remoteVersion` until the next successful push.
The next push uses that `remoteVersion` as the optimistic concurrency base.

## Create / Update Rules

### `BabyRepository`
- On create default baby: assign explicit `id`, set `syncState = .pendingUpsert`.
- On name, birth date, gender, avatar, or onboarding updates: set `syncState = .pendingUpsert`.
- When avatar changes: keep local file workflow, then upload on next sync and update `remoteAvatarPath` after success.

### `RecordRepository`
- On create: assign `babyID` from current active baby and set `syncState = .pendingUpsert`.
- On update: keep current validation flow, then set `syncState = .pendingUpsert`.
- When food image changes: keep current local file cleanup rules, then upload on next sync and update `remoteImagePath` after success.

### `TreasureRepository`
- On create: assign `babyID` from active baby and set `syncState = .pendingUpsert`.
- On update/delete of photos: preserve ordered local image list and remote image path list.

## Delete Rules

Delete behavior must stay compatible with today's UI.

### Record delete
1. Delete the local `RecordItem` immediately, exactly as the current repository does.
2. Create a `SyncDeletionTombstone` with `entityType = recordItem`.
3. Set `readyAfter = now + undoWindow` for recoverable deletes, or `now` for immediate deletes.
4. Keep the existing local food-photo cleanup scheduling.
5. If the user undoes, restore the local record and delete the matching tombstone.

### Memory delete
1. Delete the local `MemoryEntry` immediately.
2. Create a tombstone with all remote image storage paths encoded in `storagePathsPayload`.
3. If the user undoes, restore the entry and delete the tombstone.

### Baby delete
Out of scope for Phase 2. There is only one active baby locally today.

## Sync Engine Architecture

### Components

```text
SyncEngine (@MainActor @Observable)
|- AuthManager
|- SupabaseService        // actor wrapper around supabase-swift client
|- SyncCursorStore
|- LocalSyncBootstrapper
|- AssetSyncService
`- RemoteChangeApplier
```

### Public shape

```swift
@MainActor @Observable
final class SyncEngine {
    var syncState: SyncUIState = .idle
    var lastSyncAt: Date?
    var pendingUpsertCount: Int = 0
    var pendingDeletionCount: Int = 0

    func scheduleSync()
    func performSync(reason: SyncReason) async
    func pushPendingUpserts() async throws
    func pushReadyDeletions() async throws
    func pullRemoteChanges() async throws
    func downloadMissingAssets() async throws
}

enum SyncUIState: Equatable {
    case idle
    case syncing(progress: String)
    case offline
    case error(String)
}
```

### Debounce

The debounce must be longer than the current 4-second undo window.

```swift
func scheduleSync() {
    syncDebounceTask?.cancel()
    syncDebounceTask = Task {
        try? await Task.sleep(for: .seconds(5))
        guard !Task.isCancelled else { return }
        await performSync(reason: .debouncedWrite)
    }
}
```

### Sync Order

Every sync pass runs in this order:
1. Push pending baby upserts
2. Push pending record upserts
3. Push pending memory upserts
4. Push ready tombstones
5. Pull remote baby changes
6. Pull remote record changes
7. Pull remote memory changes
8. Download any missing assets referenced by local metadata

Reasoning:
- `BabyProfile` must exist remotely before child rows point to `baby_id`.
- Push runs before pull so the common path preserves the user's current device edits.
- Tombstones run after upserts so create/update beats delete when both are still locally pending.

### Push Rules

### Insert
- If `remoteVersion == nil`, upsert by fixed UUID.
- On success, save returned `version`, `updated_at`, and any remote storage paths.
- Set `syncState = .synced`.

### Update
- If `remoteVersion != nil`, update with optimistic concurrency:
  - `WHERE id = :id AND version = :remoteVersion`
- On success, save the returned incremented `version` and set `syncState = .synced`.

### Version mismatch

This phase keeps record-level LWW but stops depending on device clocks.

Algorithm:
1. Attempt update with current `remoteVersion`.
2. If zero rows are affected, fetch the latest remote row.
3. Retry exactly once using the latest remote `version` and the current local payload.
4. If retry succeeds, the local payload becomes the latest server write.
5. If retry still fails, abort sync, surface error state, and leave the row dirty for the next attempt.

This gives a deterministic server-ordered LWW policy without comparing device time to server time.

### Delete

For each `SyncDeletionTombstone` where `readyAfter <= now`:
1. Soft-delete the remote row by setting `deleted_at = now()`.
2. Remove remote storage objects referenced by `storagePathsPayload`, if any.
3. Remove the tombstone locally only after both steps succeed.

If the remote row does not exist anymore, treat delete as idempotent success and remove the tombstone.

### Pull Rules

### Cursor model

Each table uses its own cursor from `SyncCursorStore`.

For each table:
1. Ask Supabase for `serverNow` before the fetch starts.
2. Fetch rows where `updated_at > cursor` and `updated_at <= serverNow`, ordered by `updated_at ASC, id ASC`.
3. Apply those rows locally.
4. Persist the new cursor only after the entire table apply succeeds.

This avoids missing changes that land during the pull itself.

### Apply rules

For each remote row:
- If no local row exists and `deleted_at IS NULL`: insert it locally.
- If no local row exists and `deleted_at IS NOT NULL`: ignore it.
- If a local row exists and `syncState == .pendingUpsert`: skip overwrite for now. The push path owns conflict resolution.
- If a local row exists and `deleted_at IS NOT NULL`: delete local row and local cached assets.
- Otherwise: overwrite local fields, set `remoteVersion`, set `syncState = .synced`.

`WeeklyLetter` is recomputed locally after memory changes are applied.

### Asset Sync Rules

The remote database stores only storage paths.
The app continues to render from local disk.

### Upload
- Food photos: upload `RecordItem.imageURL` to `food-photos/{userId}/{recordId}.jpg`
- Treasure photos: upload each local treasure image to `treasure-photos/{userId}/{memoryId}/{assetId}.jpg`
- Baby avatar: upload `BabyProfile.avatarPath` to `baby-avatars/{userId}/{babyId}.jpg`

After upload success:
- persist the storage path(s) on the local model
- include those path(s) in the next metadata upsert if needed

### Download
After pull, for any remote storage path that does not have a local cached file:
1. Download from Supabase Storage
2. Save to the existing local photo/avatar directories
3. Update the local path field (`imageURL`, `imageLocalPath`, `avatarPath`) without marking the model dirty again

`downloadMissingAssets()` must not convert a synced row back into `pendingUpsert`.

## Auth Manager

```swift
@MainActor @Observable
final class AuthManager {
    var currentUser: User?
    var authState: AuthState = .unauthenticated
    var linkedUserID: UUID?

    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func signOut() async throws
    func restoreSession() async
}

enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(userID: UUID)
    case blockedByAccountBinding
    case error(String)
}
```

### Auth Flow Requirements

### `restoreSession()`
1. Read the Supabase session from Keychain via `supabase-swift`.
2. If no session exists, remain unauthenticated.
3. If a session exists, validate it against the local `linkedUserID` rule.
4. Run `LocalSyncBootstrapper` if needed.
5. Load the sync cursor namespace for that user.
6. Schedule immediate sync.

### `signIn` / `signUp`
1. Authenticate with Supabase.
2. Check account binding.
3. If local store is unlinked, save `linkedUserID`.
4. Run bootstrap if needed.
5. Trigger immediate sync.

### `signOut`
1. End the Supabase session.
2. Keep local SwiftData and local files intact.
3. Cancel in-flight sync tasks.
4. Keep `linkedUserID` so the same user can sign back in safely later.

## Supabase Service

Use a wrapper named `SupabaseService`, not `SupabaseClient`, to avoid naming collision with the SDK type.

```swift
actor SupabaseService {
    private let sdkClient: SupabaseClient

    init(url: URL, anonKey: String)

    // Auth
    func signIn(email: String, password: String) async throws -> Session
    func signUp(email: String, password: String) async throws -> Session
    func signOut() async throws
    func restoreSession() async throws -> Session?
    func currentUser() async -> User?

    // Server time
    func fetchServerNow() async throws -> Date

    // Database upserts
    func upsertBabyProfile(_ dto: BabyProfileDTO) async throws -> BabyProfileDTO
    func upsertRecordItem(_ dto: RecordItemDTO) async throws -> RecordItemDTO
    func upsertMemoryEntry(_ dto: MemoryEntryDTO) async throws -> MemoryEntryDTO

    // Optimistic updates
    func updateBabyProfile(_ dto: BabyProfileDTO, expectedVersion: Int64) async throws -> BabyProfileDTO
    func updateRecordItem(_ dto: RecordItemDTO, expectedVersion: Int64) async throws -> RecordItemDTO
    func updateMemoryEntry(_ dto: MemoryEntryDTO, expectedVersion: Int64) async throws -> MemoryEntryDTO

    // Fetch current remote version when optimistic update misses
    func fetchBabyProfile(id: UUID) async throws -> BabyProfileDTO?
    func fetchRecordItem(id: UUID) async throws -> RecordItemDTO?
    func fetchMemoryEntry(id: UUID) async throws -> MemoryEntryDTO?

    // Incremental pull
    func fetchBabyProfiles(updatedAfter: Date?, upTo upperBound: Date, userID: UUID) async throws -> [BabyProfileDTO]
    func fetchRecordItems(updatedAfter: Date?, upTo upperBound: Date, userID: UUID) async throws -> [RecordItemDTO]
    func fetchMemoryEntries(updatedAfter: Date?, upTo upperBound: Date, userID: UUID) async throws -> [MemoryEntryDTO]

    // Soft delete
    func softDelete(table: SupabaseTable, id: UUID) async throws

    // Storage
    func uploadImage(bucket: StorageBucket, path: String, data: Data) async throws
    func downloadImage(bucket: StorageBucket, path: String) async throws -> Data
    func removeImage(bucket: StorageBucket, path: String) async throws
}
```

### DTO Rules

- DTOs use the same UUID as local models.
- DTOs carry `version`, `updatedAt`, and remote storage path fields.
- `MemoryEntryDTO.imageStoragePaths` is `[String]`, not a single string.
- `BabyProfileDTO` includes `isActive` and `hasCompletedOnboarding` so cross-device state stays consistent.

## Configuration

The repo currently does not have an `Environment.get(...)` helper. Do not invent one.

Use this configuration approach:
1. Create `Config/Supabase.xcconfig.example` committed to git.
2. Create `Config/Supabase.local.xcconfig` ignored by git.
3. Wire target build settings so `SUPABASE_URL` and `SUPABASE_ANON_KEY` are exposed to `Info.plist`.
4. Read them from `Bundle.main.object(forInfoDictionaryKey:)`.

Example:

```swift
enum SupabaseConfig {
    static var url: URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: raw),
            !raw.isEmpty
        else {
            fatalError("Missing SUPABASE_URL")
        }
        return url
    }

    static var anonKey: String {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !value.isEmpty
        else {
            fatalError("Missing SUPABASE_ANON_KEY")
        }
        return value
    }
}
```

## UI Changes

### Sidebar

### New route

```swift
case account
```

### Updated rules
- `Account` is always visible.
- `Cloud Sync` is always visible in Phase 2.
- `Cloud Sync` is **not** gated by `SubscriptionManager.isEntitled(.cloudSync)` in this phase.
- `Family Group` can remain placeholder / future-gated.

Reasoning:
- Server-backed entitlement enforcement is out of scope.
- A client-only paywall is not a real permission boundary.
- The implementable version must not pretend otherwise.

## `AccountView`

### Unauthenticated state
- Email field
- Password field
- Sign In button
- Sign Up button
- Forgot Password link or placeholder copy

### Authenticated state
- Email display
- Sync status row
- Last sync time
- Sync Now button
- Sign Out button

### Bound-to-another-account state
- Blocking message
- Explains that this device is already linked to another account
- Destructive action deferred to a future reset flow

## `CloudSyncView`

### Unauthenticated
- Explains that cloud backup requires sign-in
- CTA to open `AccountView`

### Authenticated
- Sync state indicator
- Last sync time
- Pending upsert count
- Pending deletion count
- Sync Now button
- Error message if the last pass failed

### Integration with existing app shell

- Replace `CloudSyncPlaceholderView` with `CloudSyncView`.
- Add `.account` to `SidebarRoute` and `SidebarDrawer` navigation.
- Inject `AuthManager` and `SyncEngine` from `ContentView`.
- Keep `SubscriptionManager` in place for Phase 1 paywall features, but do not use it to block Phase 2 sync paths.

## File Structure

### New files

```text
sprout/Domain/Auth/
|- AuthManager.swift
`- AuthState.swift

sprout/Domain/Sync/
|- AssetSyncService.swift
|- LocalSyncBootstrapper.swift
|- SupabaseConfig.swift
|- SupabaseService.swift
|- SyncCursorStore.swift
|- SyncDeletionTombstone.swift
|- SyncEngine.swift
|- SyncModels.swift
|- SyncReason.swift
`- SyncState.swift

sprout/Features/Shell/
|- AccountView.swift
`- CloudSyncView.swift

sproutTests/
|- AuthManagerTests.swift
|- LocalSyncBootstrapperTests.swift
|- MockSupabaseService.swift
|- SyncEngineTests.swift
`- SyncRepositoryIntegrationTests.swift
```

### Modified files

| File | Change |
|------|--------|
| `sprout/Domain/Baby/BabyProfile.swift` | Add explicit `id`, remote sync metadata, remote avatar path |
| `sprout/Domain/Records/RecordItem.swift` | Add `babyID`, remote sync metadata, remote image path |
| `sprout/Domain/Treasure/MemoryEntry.swift` | Add `babyID`, remote sync metadata, remote image paths payload |
| `sprout/Domain/Baby/BabyRepository.swift` | Mark writes dirty and preserve local avatar flow |
| `sprout/Domain/Records/RecordRepository.swift` | Mark writes dirty; create deletion tombstones instead of storing pending-delete rows |
| `sprout/Domain/Treasure/TreasureRepository.swift` | Mark writes dirty; preserve multi-image remote metadata |
| `sprout/Features/Shell/SidebarDrawer.swift` | Add `.account`; remove Cloud Sync Pro gate |
| `sprout/Features/Shell/SidebarMenuView.swift` | Add account menu item and update cloud sync copy |
| `sprout/ContentView.swift` | Create/inject `AuthManager` and `SyncEngine`; run session restore/bootstrap |
| `sprout/SproutApp.swift` | Register migration plan and sync-related models |
| `sprout.xcodeproj/project.pbxproj` | Add `supabase-swift` package and new source files |

### Deleted files

| File | Reason |
|------|--------|
| `sprout/Features/Shell/CloudSyncPlaceholderView.swift` | Replaced by `CloudSyncView` |

## Testing

### Unit Tests

### `LocalSyncBootstrapperTests`
- `test_bootstrap_assignsIDToLegacyBabyProfile`
- `test_bootstrap_backfillsRecordBabyIDs`
- `test_bootstrap_backfillsMemoryBabyIDs`
- `test_bootstrap_marksLegacyRowsPendingUpsert`

### `SyncEngineTests`
- `test_scheduleSync_waitsFiveSeconds`
- `test_pushInsert_setsRemoteVersionAndSynced`
- `test_pushUpdate_usesExpectedVersion`
- `test_pushVersionMismatch_refetchesAndRetriesOnce`
- `test_pushReadyDeletion_softDeletesRemoteAndRemovesTombstone`
- `test_pull_insertsMissingRemoteRows`
- `test_pull_overwritesCleanLocalRows`
- `test_pull_skipsDirtyLocalRows`
- `test_pull_ignoresSoftDeletedRowsWhenLocalMissing`
- `test_downloadMissingAssets_doesNotMarkRowsDirty`

### `AuthManagerTests`
- `test_restoreSession_withoutSession_staysUnauthenticated`
- `test_signIn_linksLocalStoreWhenUnbound`
- `test_signIn_withDifferentLinkedUser_blocksAccountBinding`
- `test_signOut_preservesLinkedUserAndLocalData`

### Repository tests
- `test_deleteRecord_createsTombstoneAndRemovesLocalRow`
- `test_restoreDeletedRecord_removesMatchingTombstone`
- `test_deleteMemoryEntry_preservesRemoteImagePathsInTombstone`

### Integration Tests

Use a dedicated Supabase test project.

Required end-to-end scenarios:
1. Sign up -> auth trigger creates `profiles` row.
2. Legacy local data -> first sign-in uploads baby, records, memories, and images.
3. Device A creates data -> Device B pulls the same data.
4. Device A edits synced record -> server `version` increments -> Device B receives updated row.
5. Device A deletes a record -> tombstone soft-deletes remote row -> Device B removes local row.
6. Memory entry with multiple images round-trips without losing order or count.
7. App relaunch restores session and resumes sync safely.

## Implementation Order

1. Supabase schema, triggers, RLS, and storage buckets
2. SwiftData migration plan and `LocalSyncBootstrapper`
3. `SupabaseService` and `SupabaseConfig`
4. `AuthManager` with account binding
5. Repository dirty-marking and tombstones
6. `SyncEngine` push/pull/asset flows
7. `AccountView` and `CloudSyncView`
8. Unit tests
9. Supabase integration tests

## Follow-Ups After Phase 2

These are deliberately deferred:
- Family group sharing over shared `baby_id` ownership
- True paid entitlement enforcement backed by the server
- Manual conflict resolution UI
- Safe account switching with local reset/import flow
- Sign in with Apple
