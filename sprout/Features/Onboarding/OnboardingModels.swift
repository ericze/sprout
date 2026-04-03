import Foundation
import SwiftData

enum OnboardingMigration {
    private static let completionKey = "hasCompletedOnboarding"

    static func shouldSkipOnboarding(
        babyRepository: BabyRepository,
        defaults: UserDefaults
    ) -> Bool {
        guard defaults.object(forKey: completionKey) == nil else {
            return defaults.bool(forKey: completionKey)
        }
        guard let baby = babyRepository.activeBaby else {
            return false
        }
        return baby.name != "宝宝"
    }

    static func migrateIfNeeded(
        babyRepository: BabyRepository,
        defaults: UserDefaults
    ) {
        guard shouldSkipOnboarding(babyRepository: babyRepository, defaults: defaults) else {
            return
        }
        defaults.set(true, forKey: completionKey)
    }
}

enum OnboardingStep: Int, CaseIterable {
    case identity
    case permissions
}

struct OnboardingDraft {
    var name: String = ""
    var birthDate: Date = .now

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }
}
