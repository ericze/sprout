import Testing
import SwiftData
@testable import sprout

@MainActor
struct OnboardingMigrationTests {

    @Test("迁移：已有自定义名字的宝宝跳过 onboarding")
    func testMigrationSkipsOnboarding() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()

        repo.createDefaultIfNeeded()
        repo.updateName("小花生")

        let shouldSkip = OnboardingMigration.shouldSkipOnboarding(
            babyRepository: repo,
            defaults: env.defaults
        )
        #expect(shouldSkip == true)
    }

    @Test("迁移：全新用户需要走 onboarding")
    func testNewUserNeedsOnboarding() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()

        let shouldSkip = OnboardingMigration.shouldSkipOnboarding(
            babyRepository: repo,
            defaults: env.defaults
        )
        #expect(shouldSkip == false)
    }

    @Test("迁移：默认名 '宝宝' 仍需走 onboarding")
    func testDefaultNameStillNeedsOnboarding() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()

        repo.createDefaultIfNeeded()

        let shouldSkip = OnboardingMigration.shouldSkipOnboarding(
            babyRepository: repo,
            defaults: env.defaults
        )
        #expect(shouldSkip == false)
    }

    @Test("迁移完成后标记 hasCompletedOnboarding")
    func testMigrationMarksComplete() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        repo.createDefaultIfNeeded()
        repo.updateName("小花生")

        let key = "hasCompletedOnboarding"
        #expect(env.defaults.bool(forKey: key) == false)

        OnboardingMigration.migrateIfNeeded(
            babyRepository: repo,
            defaults: env.defaults
        )

        #expect(env.defaults.bool(forKey: key) == true)
    }
}
