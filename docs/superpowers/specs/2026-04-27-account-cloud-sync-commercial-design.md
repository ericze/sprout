# Account + Cloud Sync Commercialization Design

**Date:** 2026-04-27
**Release:** Sprout 1.3
**Status:** Approved for implementation planning

## Goal

Make Account and Cloud Sync a real 1.3 capability backed by Supabase Auth, Postgres, Storage, RLS, and the existing local-first SwiftData model.

This slice does not implement Family Group, Multi-Baby UI, server-side subscription entitlement checks, or cross-account switching. It creates the trusted identity and sync foundation those later slices depend on.

## Current Context

The app already has local-first record, growth, treasure, onboarding, i18n, StoreKit, account UI, cloud sync UI, sync status state, and a `SyncEngine`.

The main gap is that `SupabaseService` is still a stub. The app has DTOs, repositories, tombstones, asset sync services, and tests around mocked sync behavior, but it cannot yet authenticate, read, write, upload, or download against the real Supabase project.

The Supabase project for this slice is:

- Project name: `sprout-13`
- Project ref: `vjfazuwkmafqmcuerpbu`
- SDK base URL: `https://vjfazuwkmafqmcuerpbu.supabase.co`
- Local app config: `Config/Supabase.local.xcconfig`

No secret key, service-role key, or database password is stored in the repo.

## Product Rules

1. Local record flows must remain usable without network, login, or successful sync.
2. Sign in enables backup and multi-device restore; it must not become a prerequisite for daily use.
3. One local SwiftData store binds to one Supabase user ID.
4. Signing out pauses backup but keeps local records.
5. A different account attempting to use an already-bound local store is blocked, not merged.
6. Cloud Sync is available to authenticated users in this slice; Pro enforcement is deferred until the Pro entitlement slice.
7. Weekly letters remain local/generated content and are recomputed from synced inputs instead of synced as first-class remote rows.

## Supabase Schema

### `profiles`

Purpose: mirror `auth.users` into a public table so app-owned rows can reference a stable user row.

Fields:

- `id uuid primary key references auth.users(id) on delete cascade`
- `email text not null default ''`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Trigger:

- On `auth.users` insert or email update, upsert the matching `profiles` row.

RLS:

- Authenticated users can select only their own profile.
- Users cannot insert or update profiles directly from the client; the trigger owns writes.

### `baby_profiles`

Purpose: remote representation of `BabyProfile`.

Fields:

- `id uuid primary key`
- `user_id uuid not null references public.profiles(id) on delete cascade`
- `name text not null`
- `birth_date timestamptz not null`
- `gender text`
- `avatar_storage_path text`
- `is_active boolean not null default true`
- `has_completed_onboarding boolean not null default false`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`
- `version bigint not null default 1`
- `deleted_at timestamptz`

Indexes:

- `(user_id)`
- `(updated_at)`

RLS:

- Authenticated users can select, insert, update, and soft-delete only rows where `user_id = auth.uid()`.

### `record_items`

Purpose: remote representation of feeding, diaper, sleep, food, and growth records.

Fields:

- `id uuid primary key`
- `user_id uuid not null references public.profiles(id) on delete cascade`
- `baby_id uuid not null references public.baby_profiles(id) on delete cascade`
- `type text not null`
- `timestamp timestamptz not null`
- `value double precision`
- `left_nursing_seconds integer not null default 0`
- `right_nursing_seconds integer not null default 0`
- `sub_type text`
- `image_storage_path text`
- `ai_summary text`
- `tags jsonb`
- `note text`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`
- `version bigint not null default 1`
- `deleted_at timestamptz`

Indexes:

- `(user_id)`
- `(baby_id)`
- `(timestamp desc)`
- `(updated_at)`

RLS:

- Authenticated users can select, insert, update, and soft-delete only rows where `user_id = auth.uid()`.

### `memory_entries`

Purpose: remote representation of treasure memories.

Fields:

- `id uuid primary key`
- `user_id uuid not null references public.profiles(id) on delete cascade`
- `baby_id uuid not null references public.baby_profiles(id) on delete cascade`
- `created_at timestamptz not null`
- `age_in_days integer`
- `image_storage_paths jsonb not null default '[]'::jsonb`
- `note text`
- `is_milestone boolean not null default false`
- `updated_at timestamptz not null default now()`
- `version bigint not null default 1`
- `deleted_at timestamptz`

Indexes:

- `(user_id)`
- `(baby_id)`
- `(updated_at)`

RLS:

- Authenticated users can select, insert, update, and soft-delete only rows where `user_id = auth.uid()`.

## Database Functions

### Server Time

Create `public.server_now()` returning `now()` so the client can take a server-authored upper-bound timestamp before incremental pulls.

### Versioned Upserts

Create RPC functions for version-checked upsert paths:

- `upsert_baby_profile(payload jsonb, expected_version bigint)`
- `upsert_record_item(payload jsonb, expected_version bigint)`
- `upsert_memory_entry(payload jsonb, expected_version bigint)`

Rules:

- The function rejects writes where `payload.user_id != auth.uid()`.
- New rows start at `version = 1`.
- Existing rows require `expected_version` to match the current row version.
- Successful updates increment `version` and set `updated_at = now()`.
- Returned rows are the canonical server rows.

### Soft Deletes

Create `soft_delete_row(table_name text, row_id uuid, expected_version bigint)`.

Rules:

- Only allow `baby_profiles`, `record_items`, and `memory_entries`.
- Reject delete if the row does not belong to `auth.uid()`.
- Require version match when the local row has a remote version.
- Set `deleted_at = now()`, increment `version`, and set `updated_at = now()`.

## Storage

Create private buckets:

- `food-photos`
- `treasure-photos`
- `baby-avatars`

Path convention:

- `food-photos/{user_id}/{record_id}.jpg`
- `treasure-photos/{user_id}/{memory_id}/{image_id}.jpg`
- `baby-avatars/{user_id}/{baby_id}.jpg`

Storage RLS:

- Authenticated users can read, write, and delete only paths whose first path segment is their `auth.uid()`.
- Buckets stay private; the app uses authenticated SDK downloads, not public URLs.

## App Architecture

### `SupabaseService`

Replace the stubbed implementation with real Supabase SDK calls:

- Restore session
- Sign in
- Sign up
- Sign out
- Fetch server time
- Versioned upsert through RPC
- Incremental fetch from tables
- Soft delete through RPC
- Upload asset
- Download asset
- Delete asset

The service remains behind the existing `SupabaseServicing` protocol so tests keep using mocks.

### `AuthManager`

Keep the existing one-local-store-to-one-account binding:

- First successful auth persists `linkedUserID`.
- Matching sessions authenticate normally.
- Mismatched sessions become `blockedByAccountBinding`.
- Sign out clears remote session only, not local data or `linkedUserID`.

### `SyncEngine`

Keep the existing flow:

1. Push pending local changes.
2. Pull remote changes bounded by `server_now()`.
3. Download missing assets after metadata apply.
4. Recompute affected weekly letters from synced memories.
5. Save per-user cursors only after successful apply.

The implementation must avoid device-clock conflict resolution. Server `updated_at` and server `version` are authoritative.

### Cloud Sync UI

The current `CloudSyncView` remains the user-facing control surface:

- Unauthenticated users see a calm account prompt.
- Authenticated users see pending counts, last sync, error state, and manual sync.
- Sync errors are visible but low-noise.

## Error Handling

- Auth errors surface in `AccountView`.
- Sync errors surface in `CloudSyncView`.
- Storage upload/download failures fail the current sync attempt but do not block local record usage.
- Version conflicts remain in `SyncEngine` as typed errors and should be testable.
- No error path deletes local data automatically.

## Testing Strategy

### Unit Tests

Keep and extend existing mock-backed tests:

- `AuthManagerTests`
- `SyncEngineTests`
- `CloudSyncStatusStoreTests`
- `SupabaseConfigTests`

### Integration Smoke

Add a script or test entry point that can run manually against `sprout-13` with local config:

1. Sign up or sign in a test user.
2. Create local baby, record, and memory.
3. Trigger full sync.
4. Verify rows exist remotely.
5. Clear local in-memory test store.
6. Restore session and pull data.
7. Verify metadata and asset round-trip.

The integration smoke must not require committing secrets.

## Acceptance Criteria

1. A user can sign up and sign in against the real Supabase project.
2. `restoreSession()` correctly restores an authenticated user after app restart.
3. Local baby profiles, records, and memories push to Supabase.
4. A second local store using the same user can pull the synced data.
5. Food photos, treasure photos, and baby avatars upload and download through private buckets.
6. Sign out does not delete local data.
7. A mismatched account cannot merge into an already-bound local store.
8. Manual Sync reports success or a visible, actionable error.
9. All existing unit tests still pass.

## Explicit Non-Goals

- Family Group invitation or membership.
- Multi-Baby management UI.
- Server-side subscription receipt validation.
- Cloud Sync Pro gating.
- Sign in with Apple.
- Realtime subscriptions.
- Manual conflict resolution center.
- Automatic cross-account local data reset.
