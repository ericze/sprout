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

        #expect(repo.createDefaultIfNeeded() == true)

        let baby = repo.activeBaby
        #expect(baby != nil)
        #expect(baby?.isActive == true)
        #expect(baby?.gender == nil)
        #expect(baby?.syncState == .pendingUpsert)
    }

    @Test("createDefaultIfNeeded does not duplicate when baby exists")
    func testNoDuplicate() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()

        #expect(repo.createDefaultIfNeeded() == true)
        #expect(repo.createDefaultIfNeeded() == true)

        let descriptor = FetchDescriptor<BabyProfile>()
        let babies = try env.modelContext.fetch(descriptor)
        #expect(babies.count == 1)
    }

    @Test("updateName persists change")
    func testUpdateName() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        #expect(repo.createDefaultIfNeeded() == true)

        #expect(repo.updateName("小花生") == true)

        #expect(repo.activeBaby?.name == "小花生")
        #expect(repo.activeBaby?.syncState == .pendingUpsert)
    }

    @Test("updateBirthDate persists change")
    func testUpdateBirthDate() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        #expect(repo.createDefaultIfNeeded() == true)

        let newDate = Date(timeIntervalSinceNow: -86400 * 100)
        #expect(repo.updateBirthDate(newDate) == true)

        #expect(repo.activeBaby?.birthDate == newDate)
        #expect(repo.activeBaby?.syncState == .pendingUpsert)
    }

    @Test("updateGender persists change")
    func testUpdateGender() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        #expect(repo.createDefaultIfNeeded() == true)

        #expect(repo.updateGender(.male) == true)
        #expect(repo.activeBaby?.gender == .male)
        #expect(repo.activeBaby?.syncState == .pendingUpsert)

        #expect(repo.updateGender(nil) == true)
        #expect(repo.activeBaby?.gender == nil)
        #expect(repo.activeBaby?.syncState == .pendingUpsert)
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
        #expect(repo.createDefaultIfNeeded() == true)
        state.updateFrom(repo.activeBaby)

        #expect(repo.updateName("小花生") == true)

        #expect(state.headerConfig.babyName == "小花生")
    }

    @Test("updateBirthDate syncs to ActiveBabyState")
    func testUpdateBirthDateSyncsState() async throws {
        let env = try makeTestEnvironment(now: .now)
        let state = ActiveBabyState()
        let repo = env.makeBabyRepository(activeBabyState: state)
        #expect(repo.createDefaultIfNeeded() == true)
        state.updateFrom(repo.activeBaby)

        let newDate = Date(timeIntervalSinceNow: -86400 * 200)
        #expect(repo.updateBirthDate(newDate) == true)

        #expect(state.headerConfig.birthDate == newDate)
    }

    @Test("updateGender syncs to ActiveBabyState via headerConfig")
    func testUpdateGenderSyncsState() async throws {
        let env = try makeTestEnvironment(now: .now)
        let state = ActiveBabyState()
        let repo = env.makeBabyRepository(activeBabyState: state)
        #expect(repo.createDefaultIfNeeded() == true)
        state.updateFrom(repo.activeBaby)

        let originalName = state.headerConfig.babyName
        #expect(repo.updateGender(.male) == true)

        #expect(state.headerConfig.babyName == originalName)
    }

    @Test("updateName without ActiveBabyState does not crash")
    func testUpdateNameWithoutState() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        #expect(repo.createDefaultIfNeeded() == true)

        #expect(repo.updateName("安全测试") == true)
        #expect(repo.activeBaby?.name == "安全测试")
    }

    @Test("markOnboardingCompleted persists explicit completion state")
    func testMarkOnboardingCompleted() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        #expect(repo.createDefaultIfNeeded() == true)

        #expect(repo.markOnboardingCompleted() == true)

        #expect(repo.activeBaby?.hasCompletedOnboarding == true)
        #expect(repo.activeBaby?.syncState == .pendingUpsert)
    }

    @Test("createBaby creates a second active baby and deactivates the previous one")
    func testCreateSecondBabyActivatesNewBaby() async throws {
        let env = try makeTestEnvironment(now: .now)
        let state = ActiveBabyState()
        let repo = env.makeBabyRepository(activeBabyState: state)
        #expect(repo.createDefaultIfNeeded() == true)
        let firstBaby = try #require(repo.activeBaby)

        let secondBaby = try #require(repo.createBaby(name: "小栗子", birthDate: env.now.value))

        let babies = try repo.fetchBabies()
        #expect(babies.count == 2)
        #expect(secondBaby.isActive == true)
        #expect(firstBaby.isActive == false)
        #expect(repo.activeBaby?.id == secondBaby.id)
        #expect(state.headerConfig.babyID == secondBaby.id)
    }

    @Test("free entitlement keeps the first baby but blocks creating a second baby")
    func freeEntitlementBlocksSecondBabyWithoutDeletingExistingData() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = BabyRepository(
            modelContext: env.modelContext,
            canCreateAdditionalBaby: { existingBabyCount in existingBabyCount == 0 }
        )
        #expect(repo.createDefaultIfNeeded() == true)
        let firstBaby = try #require(repo.activeBaby)

        let secondBaby = repo.createBaby(name: "小栗子", birthDate: env.now.value)

        let babies = try repo.fetchBabies()
        #expect(secondBaby == nil)
        #expect(babies.count == 1)
        #expect(babies.first?.id == firstBaby.id)
        #expect(babies.first?.name == firstBaby.name)
    }

    @Test("expired entitlement preserves existing babies but blocks adding another")
    func expiredEntitlementBlocksAdditionalBabyWithoutDeletingExistingData() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        #expect(repo.createDefaultIfNeeded() == true)
        let secondBaby = try #require(repo.createBaby(name: "小栗子", birthDate: env.now.value))

        let expiredRepo = BabyRepository(
            modelContext: env.modelContext,
            canCreateAdditionalBaby: { _ in false }
        )
        let thirdBaby = expiredRepo.createBaby(name: "小松果", birthDate: env.now.value)

        let babies = try expiredRepo.fetchBabies()
        #expect(thirdBaby == nil)
        #expect(babies.count == 2)
        #expect(babies.contains { $0.id == secondBaby.id })
    }

    @Test("activateBaby switches the active baby and syncs header state")
    func testActivateBabySwitchesActiveBaby() async throws {
        let env = try makeTestEnvironment(now: .now)
        let state = ActiveBabyState()
        let repo = env.makeBabyRepository(activeBabyState: state)
        #expect(repo.createDefaultIfNeeded() == true)
        let firstBaby = try #require(repo.activeBaby)
        _ = try #require(repo.createBaby(name: "小栗子", birthDate: env.now.value))

        #expect(repo.activateBaby(id: firstBaby.id) == true)

        let babies = try repo.fetchBabies()
        #expect(babies.first { $0.id == firstBaby.id }?.isActive == true)
        #expect(babies.filter { $0.isActive }.count == 1)
        #expect(repo.activeBaby?.id == firstBaby.id)
        #expect(state.headerConfig.babyID == firstBaby.id)
    }

    @Test("update methods fail safely when no active baby exists")
    func testUpdateMethodsFailWhenNoActiveBaby() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()

        #expect(repo.updateName("Noop") == false)
        #expect(repo.updateBirthDate(.now) == false)
        #expect(repo.updateGender(.female) == false)
        #expect(repo.markOnboardingCompleted() == false)
    }
}
