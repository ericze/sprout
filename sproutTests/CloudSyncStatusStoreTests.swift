import Foundation
import SwiftData
import Testing
@testable import sprout

@MainActor
struct CloudSyncStatusStoreTests {
    @Test("manual sync uses the configured sync engine and clears pending changes")
    func manualSyncPushesPendingChanges() async throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_711_000_000))
        let userID = UUID()
        let baby = BabyProfile(name: "Sprout", birthDate: environment.now.value)
        environment.modelContext.insert(baby)
        try environment.modelContext.save()

        let mock = MockSupabaseService()
        let engine = SyncEngine(
            modelContext: environment.modelContext,
            supabaseService: mock,
            currentUserIDProvider: { userID },
            nowProvider: { environment.now.value }
        )
        let store = CloudSyncStatusStore()
        store.configure(syncEngine: engine)

        #expect(store.pendingChangeCount == 1)
        #expect(store.pendingDeletionCount == 0)

        await store.syncIfEligible(
            authState: .authenticated(userID: userID),
            reason: .manual
        )

        #expect(await mock.readOperations() == [
            .upsertBabyProfile(id: baby.id, expectedVersion: nil, avatarStoragePath: nil)
        ])
        #expect(store.phase == .idle)
        #expect(store.pendingChangeCount == 0)
        #expect(store.lastSyncAt == environment.now.value)
    }
}
