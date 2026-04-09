import Foundation

enum SupabaseTable: String, CaseIterable, Sendable {
    case profiles
    case babyProfiles = "baby_profiles"
    case recordItems = "record_items"
    case memoryEntries = "memory_entries"
}

enum StorageBucket: String, CaseIterable, Sendable {
    case foodPhotos = "food-photos"
    case treasurePhotos = "treasure-photos"
    case babyAvatars = "baby-avatars"
}

struct SupabaseAuthUser: Equatable, Sendable {
    let id: UUID
    let email: String?
}

struct SupabaseSession: Equatable, Sendable {
    let user: SupabaseAuthUser
}

struct BabyProfileDTO: Codable, Equatable, Sendable {
    let id: UUID
    let userID: UUID
    let name: String
    let birthDate: Date
    let gender: String?
    let avatarStoragePath: String?
    let isActive: Bool
    let hasCompletedOnboarding: Bool
    let createdAt: Date
    let updatedAt: Date
    let version: Int64
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case birthDate = "birth_date"
        case gender
        case avatarStoragePath = "avatar_storage_path"
        case isActive = "is_active"
        case hasCompletedOnboarding = "has_completed_onboarding"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case version
        case deletedAt = "deleted_at"
    }
}

struct RecordItemDTO: Codable, Equatable, Sendable {
    let id: UUID
    let userID: UUID
    let babyID: UUID
    let type: String
    let timestamp: Date
    let value: Double?
    let leftNursingSeconds: Int
    let rightNursingSeconds: Int
    let subType: String?
    let imageStoragePath: String?
    let aiSummary: String?
    let tags: [String]?
    let note: String?
    let createdAt: Date
    let updatedAt: Date
    let version: Int64
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case babyID = "baby_id"
        case type
        case timestamp
        case value
        case leftNursingSeconds = "left_nursing_seconds"
        case rightNursingSeconds = "right_nursing_seconds"
        case subType = "sub_type"
        case imageStoragePath = "image_storage_path"
        case aiSummary = "ai_summary"
        case tags
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case version
        case deletedAt = "deleted_at"
    }
}

struct MemoryEntryDTO: Codable, Equatable, Sendable {
    let id: UUID
    let userID: UUID
    let babyID: UUID
    let createdAt: Date
    let ageInDays: Int?
    let imageStoragePaths: [String]
    let note: String?
    let isMilestone: Bool
    let updatedAt: Date
    let version: Int64
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case babyID = "baby_id"
        case createdAt = "created_at"
        case ageInDays = "age_in_days"
        case imageStoragePaths = "image_storage_paths"
        case note
        case isMilestone = "is_milestone"
        case updatedAt = "updated_at"
        case version
        case deletedAt = "deleted_at"
    }
}
