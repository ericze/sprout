# DEV-E Cloud Sync Failure Recovery and Schema QA Design

## Goal

Harden Cloud Sync failure recovery for Sprout 1.3 without changing the local-first product contract.

## Scope

- Add automated coverage for offline/server failure, authentication loss, retry recovery, and preserving local pending data.
- Add automated coverage for deletion tombstone preservation when remote deletion fails.
- Strengthen SwiftData startup/schema QA so the current migration plan does not reintroduce duplicate version checksum failures.
- Update the 1.3 QA document to reflect which DEV-E cases are covered by automation and which still require real-device QA.

## Approach

The implementation stays inside the existing `SyncEngine`, `MockSupabaseService`, and `SproutAppStartupTests` test surface. Production behavior should only change if a failing test exposes a real gap. The mock service gets narrow failure injection points that model Supabase/network failures without adding a second test harness.

## Error Handling Contract

- If the current user is unavailable, sync fails with an error phase and does not push, pull, delete, or clear local data.
- If a network/server operation fails, rows that were not successfully synced remain `pendingUpsert`, and deletion tombstones remain queued.
- A later manual retry uses the same pending rows/tombstones and can complete normally.
- SwiftData schema startup uses the committed migration plan and keeps every version's model shape unique.

## Testing

Use Swift Testing against the existing `sproutTests` target. Focused verification runs should cover:

- `SyncEngineTests`
- `SproutAppStartupTests`

Full suite can remain simulator-dependent; if local simulator selection blocks execution, report the exact command and failure.
