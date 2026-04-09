import Foundation
import Testing
@testable import sprout

@MainActor
struct SyncCursorStoreTests {
    @Test("SyncCursorStore persists a cursor per linked user")
    func savesAndLoadsPerUser() {
        let suiteName = "sync-cursor-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = SyncCursorStore(defaults: defaults)
        let userID = UUID()
        let cursor = SyncCursor(
            babyProfilesAt: Date(timeIntervalSince1970: 10),
            recordItemsAt: Date(timeIntervalSince1970: 20),
            memoryEntriesAt: Date(timeIntervalSince1970: 30)
        )

        store.save(cursor, for: userID)

        #expect(store.load(for: userID) == cursor)
    }

    @Test("SyncCursorStore keeps namespaces isolated")
    func isolatesUsers() {
        let suiteName = "sync-cursor-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = SyncCursorStore(defaults: defaults)
        let firstUser = UUID()
        let secondUser = UUID()

        store.save(SyncCursor(recordItemsAt: Date(timeIntervalSince1970: 40)), for: firstUser)

        #expect(store.load(for: secondUser) == SyncCursor())
    }
}
