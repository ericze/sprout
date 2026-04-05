import Foundation
import Testing
import SwiftData
@testable import sprout

@MainActor
struct OnboardingMigrationTests {

    @Test("new users still need onboarding")
    func testNewUserNeedsOnboarding() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()

        #expect(
            OnboardingMigration.shouldSkipOnboarding(
                babyRepository: repo,
                defaults: env.defaults,
                now: env.now.value
            ) == false
        )
    }

    @Test("real names matching placeholder values do not skip onboarding")
    func testPlaceholderNameDoesNotSkipOnboarding() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()

        repo.createDefaultIfNeeded()

        for name in ["Baby", "宝宝"] {
            repo.updateName(name)
            #expect(
                OnboardingMigration.shouldSkipOnboarding(
                    babyRepository: repo,
                    defaults: env.defaults,
                    now: env.now.value
                ) == false
            )
        }
    }

    @Test("persisted completion flag skips onboarding")
    func testPersistedCompletionFlagSkipsOnboarding() async throws {
        let env = try makeTestEnvironment(now: .now)
        let key = "hasCompletedOnboarding"

        env.defaults.set(true, forKey: key)

        #expect(
            OnboardingMigration.shouldSkipOnboarding(
                babyRepository: env.makeBabyRepository(),
                defaults: env.defaults,
                now: env.now.value
            ) == true
        )
    }

    @Test("legacy customized profiles migrate to explicit completion")
    func testLegacyCustomizedProfileMigrates() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        let key = "hasCompletedOnboarding"

        repo.createDefaultIfNeeded()
        repo.updateBirthDate(env.now.value.addingTimeInterval(-86400 * 30))
        repo.activeBaby?.createdAt = env.now.value.addingTimeInterval(-7200)

        #expect(env.defaults.object(forKey: key) == nil)
        #expect(repo.activeBaby?.hasCompletedOnboarding == false)

        OnboardingMigration.migrateIfNeeded(
            babyRepository: repo,
            defaults: env.defaults,
            now: env.now.value
        )

        #expect(env.defaults.bool(forKey: key) == true)
        #expect(repo.activeBaby?.hasCompletedOnboarding == true)
    }

    @Test("recent partially edited profiles do not skip onboarding")
    func testRecentPartialProfileDoesNotMigrate() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()

        repo.createDefaultIfNeeded()
        repo.updateBirthDate(env.now.value.addingTimeInterval(-86400 * 10))
        repo.activeBaby?.createdAt = env.now.value.addingTimeInterval(-300)

        #expect(
            OnboardingMigration.shouldSkipOnboarding(
                babyRepository: repo,
                defaults: env.defaults,
                now: env.now.value
            ) == false
        )
    }

    @Test("migration preserves explicit completion flag")
    func testMigrationPreservesExplicitCompletionFlag() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        let key = "hasCompletedOnboarding"

        env.defaults.set(true, forKey: key)
        repo.createDefaultIfNeeded()

        OnboardingMigration.migrateIfNeeded(
            babyRepository: repo,
            defaults: env.defaults,
            now: env.now.value
        )

        #expect(env.defaults.bool(forKey: key) == true)
        #expect(repo.activeBaby?.hasCompletedOnboarding == true)
    }
}
