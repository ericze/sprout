import Foundation

struct SyncCursor: Codable, Equatable, Sendable {
    var babyProfilesAt: Date?
    var recordItemsAt: Date?
    var memoryEntriesAt: Date?
}

@MainActor
final class SyncCursorStore {
    private let defaults: UserDefaults
    private let keyPrefix: String

    nonisolated init(defaults: UserDefaults = .standard, keyPrefix: String = "sync.cursor") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    func load(for userID: UUID) -> SyncCursor {
        guard let data = defaults.data(forKey: storageKey(for: userID)) else {
            return SyncCursor()
        }

        do {
            return try JSONDecoder().decode(SyncCursor.self, from: data)
        } catch {
            return SyncCursor()
        }
    }

    func save(_ cursor: SyncCursor, for userID: UUID) {
        guard let data = try? JSONEncoder().encode(cursor) else { return }
        defaults.set(data, forKey: storageKey(for: userID))
    }

    func clear(for userID: UUID) {
        defaults.removeObject(forKey: storageKey(for: userID))
    }

    private func storageKey(for userID: UUID) -> String {
        "\(keyPrefix).\(userID.uuidString.lowercased())"
    }
}
