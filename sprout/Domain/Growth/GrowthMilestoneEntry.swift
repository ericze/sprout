import Foundation
import SwiftData

@Model
final class GrowthMilestoneEntry {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var templateKey: String?
    var title: String
    var category: String
    var occurredAt: Date
    var note: String?
    var imageLocalPath: String?
    var remoteImagePath: String?
    var remoteVersion: Int64?
    var syncStateRaw: String
    var isCustom: Bool
    var createdAt: Date
    var updatedAt: Date

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pendingUpsert }
        set { syncStateRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        babyID: UUID = UUID(),
        templateKey: String? = nil,
        title: String,
        category: String,
        occurredAt: Date,
        note: String? = nil,
        imageLocalPath: String? = nil,
        remoteImagePath: String? = nil,
        remoteVersion: Int64? = nil,
        syncStateRaw: String = SyncState.pendingUpsert.rawValue,
        isCustom: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.babyID = babyID
        self.templateKey = templateKey
        self.title = title
        self.category = category
        self.occurredAt = occurredAt
        self.note = note
        self.imageLocalPath = imageLocalPath
        self.remoteImagePath = remoteImagePath
        self.remoteVersion = remoteVersion
        self.syncStateRaw = syncStateRaw
        self.isCustom = isCustom
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
