import Foundation
import SwiftData

@Model
final class BabyProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var birthDate: Date
    var gender: Gender?
    var createdAt: Date
    var avatarPath: String?
    var remoteAvatarPath: String?
    var remoteVersion: Int64?
    var syncStateRaw: String
    var isActive: Bool
    var hasCompletedOnboarding: Bool

    enum Gender: String, Codable {
        case male
        case female
    }

    /// Localized placeholder name used when no user name has been set yet.
    /// This is intentionally *not* persisted. It only seeds newly created
    /// profiles so the UI has a readable default display name.
    static var defaultName: String {
        String(localized: "common.baby.placeholder")
    }

    init(
        id: UUID = UUID(),
        name: String = BabyProfile.defaultName,
        birthDate: Date = .now,
        gender: Gender? = nil,
        createdAt: Date = .now,
        avatarPath: String? = nil,
        remoteAvatarPath: String? = nil,
        remoteVersion: Int64? = nil,
        syncStateRaw: String = SyncState.pendingUpsert.rawValue,
        isActive: Bool = true,
        hasCompletedOnboarding: Bool = false
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.createdAt = createdAt
        self.avatarPath = avatarPath
        self.remoteAvatarPath = remoteAvatarPath
        self.remoteVersion = remoteVersion
        self.syncStateRaw = syncStateRaw
        self.isActive = isActive
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pendingUpsert }
        set { syncStateRaw = newValue.rawValue }
    }
}
