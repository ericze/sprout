import Foundation
import SwiftData

@Model
final class MemoryEntry {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var createdAt: Date
    var ageInDays: Int?
    var imageLocalPath: String?
    var remoteImagePathsPayload: String?
    var remoteVersion: Int64?
    var syncStateRaw: String
    var note: String?
    var isMilestone: Bool

    var imageLocalPaths: [String] {
        get { TreasureImagePathCodec.decodeStorageValue(imageLocalPath) }
        set { imageLocalPath = TreasureImagePathCodec.encodeStorageValue(for: newValue) }
    }

    var remoteImagePaths: [String] {
        get { Self.decodeRemoteImagePaths(from: remoteImagePathsPayload) }
        set { remoteImagePathsPayload = Self.encodeRemoteImagePaths(newValue) }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pendingUpsert }
        set { syncStateRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        babyID: UUID = UUID(),
        createdAt: Date,
        ageInDays: Int?,
        imageLocalPaths: [String] = [],
        remoteImagePathsPayload: String? = nil,
        remoteVersion: Int64? = nil,
        syncStateRaw: String = SyncState.pendingUpsert.rawValue,
        note: String? = nil,
        isMilestone: Bool = false
    ) {
        self.id = id
        self.babyID = babyID
        self.createdAt = createdAt
        self.ageInDays = ageInDays
        self.imageLocalPath = TreasureImagePathCodec.encodeStorageValue(for: imageLocalPaths)
        self.remoteImagePathsPayload = remoteImagePathsPayload
        self.remoteVersion = remoteVersion
        self.syncStateRaw = syncStateRaw
        self.note = note
        self.isMilestone = isMilestone
    }

    private static func encodeRemoteImagePaths(_ paths: [String]) -> String? {
        let normalizedPaths = paths.compactMap { path -> String? in
            let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedPath.isEmpty ? nil : trimmedPath
        }
        guard !normalizedPaths.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(normalizedPaths) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodeRemoteImagePaths(from payload: String?) -> [String] {
        guard let payload, let data = payload.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}
