import Foundation
import SwiftData

enum SyncDeletionEntityType: String, Codable, CaseIterable, Sendable {
    case babyProfile
    case recordItem
    case memoryEntry
}

@Model
final class SyncDeletionTombstone {
    @Attribute(.unique) var id: UUID
    var entityTypeRaw: String
    var entityID: UUID
    var remoteVersion: Int64?
    var readyAfter: Date
    var storagePathsPayload: String?

    init(
        id: UUID = UUID(),
        entityType: SyncDeletionEntityType,
        entityID: UUID,
        remoteVersion: Int64?,
        readyAfter: Date,
        storagePathsPayload: String? = nil
    ) {
        self.id = id
        entityTypeRaw = entityType.rawValue
        self.entityID = entityID
        self.remoteVersion = remoteVersion
        self.readyAfter = readyAfter
        self.storagePathsPayload = storagePathsPayload
    }

    var entityType: SyncDeletionEntityType {
        get { SyncDeletionEntityType(rawValue: entityTypeRaw) ?? .recordItem }
        set { entityTypeRaw = newValue.rawValue }
    }

    var storagePaths: [String] {
        get { Self.decodeStoragePaths(from: storagePathsPayload) }
        set { storagePathsPayload = Self.encodeStoragePaths(newValue) }
    }

    private static func encodeStoragePaths(_ paths: [String]) -> String? {
        guard !paths.isEmpty else { return nil }
        let sanitizedPaths = paths.compactMap { path -> String? in
            let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedPath.isEmpty ? nil : trimmedPath
        }
        guard !sanitizedPaths.isEmpty else { return nil }

        guard let data = try? JSONEncoder().encode(sanitizedPaths) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodeStoragePaths(from payload: String?) -> [String] {
        guard let payload, let data = payload.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}
