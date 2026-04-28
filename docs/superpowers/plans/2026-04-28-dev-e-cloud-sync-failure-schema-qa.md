# DEV-E Cloud Sync Failure Recovery and Schema QA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add DEV-E failure recovery and schema QA coverage for Sprout 1.3.

**Architecture:** Reuse the existing `SyncEngine` and `MockSupabaseService` tests. Add narrow mock failure injection, assert local SwiftData rows/tombstones survive failed sync, verify retry success, and update the QA checklist.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing, Supabase service protocol mocks.

---

### Task 1: Sync Failure Recovery Tests

**Files:**
- Modify: `sproutTests/SyncEngineTests.swift`
- Modify: `sproutTests/MockSupabaseService.swift`

- [ ] Add failing tests for unauthenticated sync, server/offline failure, retry recovery, and failed tombstone deletion.
- [ ] Add minimal mock failure injection for server-now, baby upsert, record upsert, memory upsert, and soft-delete operations.
- [ ] Run focused `SyncEngineTests` and confirm new tests pass.

### Task 2: Schema Startup QA Tests

**Files:**
- Modify: `sproutTests/SproutAppStartupTests.swift`

- [ ] Add a direct migration-plan container startup test.
- [ ] Keep model-shape uniqueness coverage tied to `SproutSchemaRegistry.models`.
- [ ] Run focused `SproutAppStartupTests`.

### Task 3: QA Documentation and Commit

**Files:**
- Modify: `docs/1.3.0/sprout-1.3-dev-qa-spec.md`

- [ ] Mark automated DEV-E failure-recovery and schema QA items as covered.
- [ ] Keep real two-device checks marked as manual.
- [ ] Review diff, avoid staging unrelated localization changes, and commit as `test: harden cloud sync failure recovery`.
