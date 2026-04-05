import Foundation

enum OnboardingMigration {
    private static let completionKey = "hasCompletedOnboarding"
    private static let legacyProfileGraceInterval: TimeInterval = 60 * 60
    private static let onboardingCustomizationThreshold: TimeInterval = 60

    static func shouldSkipOnboarding(
        babyRepository: BabyRepository,
        defaults: UserDefaults,
        now: Date = .now
    ) -> Bool {
        if defaults.object(forKey: completionKey) != nil {
            return defaults.bool(forKey: completionKey)
        }

        guard let baby = babyRepository.activeBaby else {
            return false
        }

        if baby.hasCompletedOnboarding {
            return true
        }

        return shouldMigrateLegacyProfile(baby, now: now)
    }

    static func migrateIfNeeded(
        babyRepository: BabyRepository,
        defaults: UserDefaults,
        now: Date = .now
    ) {
        guard shouldSkipOnboarding(
            babyRepository: babyRepository,
            defaults: defaults,
            now: now
        ) else {
            return
        }

        defaults.set(true, forKey: completionKey)
        babyRepository.markOnboardingCompleted()
    }

    private static func shouldMigrateLegacyProfile(_ baby: BabyProfile, now: Date) -> Bool {
        guard baby.createdAt <= now.addingTimeInterval(-legacyProfileGraceInterval) else {
            return false
        }

        return hasCustomizedBirthDate(baby) || baby.gender != nil
    }

    private static func hasCustomizedBirthDate(_ baby: BabyProfile) -> Bool {
        abs(baby.birthDate.timeIntervalSince(baby.createdAt)) > onboardingCustomizationThreshold
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
