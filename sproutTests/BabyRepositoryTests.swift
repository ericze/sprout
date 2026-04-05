import Foundation
import Testing
import SwiftData
@testable import sprout

@MainActor
struct BabyRepositoryTests {

    @Test("createDefaultIfNeeded creates a baby when none exist")
    func testCreateDefault() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()

        repo.createDefaultIfNeeded()

        let baby = repo.activeBaby
        #expect(baby != nil)
        #expect(baby?.isActive == true)
        #expect(baby?.gender == nil)
    }

    @Test("createDefaultIfNeeded does not duplicate when baby exists")
    func testNoDuplicate() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()

        repo.createDefaultIfNeeded()
        repo.createDefaultIfNeeded()

        let descriptor = FetchDescriptor<BabyProfile>()
        let babies = try env.modelContext.fetch(descriptor)
        #expect(babies.count == 1)
    }

    @Test("updateName persists change")
    func testUpdateName() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        repo.createDefaultIfNeeded()

        repo.updateName("小花生")

        #expect(repo.activeBaby?.name == "小花生")
    }

    @Test("updateBirthDate persists change")
    func testUpdateBirthDate() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        repo.createDefaultIfNeeded()

        let newDate = Date(timeIntervalSinceNow: -86400 * 100)
        repo.updateBirthDate(newDate)

        #expect(repo.activeBaby?.birthDate == newDate)
    }

    @Test("updateGender persists change")
    func testUpdateGender() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        repo.createDefaultIfNeeded()

        repo.updateGender(.male)
        #expect(repo.activeBaby?.gender == .male)

        repo.updateGender(nil)
        #expect(repo.activeBaby?.gender == nil)
    }

    @Test("activeBaby returns nil when no babies exist")
    func testActiveBabyNil() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()

        #expect(repo.activeBaby == nil)
    }

    @Test("updateName syncs to ActiveBabyState")
    func testUpdateNameSyncsState() async throws {
        let env = try makeTestEnvironment(now: .now)
        let state = ActiveBabyState()
        let repo = env.makeBabyRepository(activeBabyState: state)
        repo.createDefaultIfNeeded()
        state.updateFrom(repo.activeBaby)

        repo.updateName("小花生")

        #expect(state.headerConfig.babyName == "小花生")
    }

    @Test("updateBirthDate syncs to ActiveBabyState")
    func testUpdateBirthDateSyncsState() async throws {
        let env = try makeTestEnvironment(now: .now)
        let state = ActiveBabyState()
        let repo = env.makeBabyRepository(activeBabyState: state)
        repo.createDefaultIfNeeded()
        state.updateFrom(repo.activeBaby)

        let newDate = Date(timeIntervalSinceNow: -86400 * 200)
        repo.updateBirthDate(newDate)

        #expect(state.headerConfig.birthDate == newDate)
    }

    @Test("updateGender syncs to ActiveBabyState via headerConfig")
    func testUpdateGenderSyncsState() async throws {
        let env = try makeTestEnvironment(now: .now)
        let state = ActiveBabyState()
        let repo = env.makeBabyRepository(activeBabyState: state)
        repo.createDefaultIfNeeded()
        state.updateFrom(repo.activeBaby)

        let originalName = state.headerConfig.babyName
        repo.updateGender(.male)

        #expect(state.headerConfig.babyName == originalName)
    }

    @Test("updateName without ActiveBabyState does not crash")
    func testUpdateNameWithoutState() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        repo.createDefaultIfNeeded()

        repo.updateName("安全测试")
        #expect(repo.activeBaby?.name == "安全测试")
    }

    @Test("markOnboardingCompleted persists explicit completion state")
    func testMarkOnboardingCompleted() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        repo.createDefaultIfNeeded()

        repo.markOnboardingCompleted()

        #expect(repo.activeBaby?.hasCompletedOnboarding == true)
    }
}
