import Foundation
import SwiftData

@Model
final class BabyProfile {
    var name: String
    var birthDate: Date
    var gender: Gender?
    var createdAt: Date
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
        name: String = BabyProfile.defaultName,
        birthDate: Date = .now,
        gender: Gender? = nil,
        createdAt: Date = .now,
        isActive: Bool = true,
        hasCompletedOnboarding: Bool = false
    ) {
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.createdAt = createdAt
        self.isActive = isActive
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}
