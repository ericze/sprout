import Testing
@testable import sprout

@MainActor
struct ActiveBabyStateTests {

    @Test("initial headerConfig defaults to placeholder")
    func testDefaultInit() {
        let state = ActiveBabyState()
        #expect(state.headerConfig.babyName == HomeHeaderConfig.placeholder.babyName)
    }

    @Test("updateFrom baby sets name and birthDate")
    func testUpdateFromBaby() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        repo.createDefaultIfNeeded()
        repo.updateName("小豆子")
        repo.updateBirthDate(Date(timeIntervalSince1970: 0))

        let state = ActiveBabyState()
        state.updateFrom(repo.activeBaby)

        #expect(state.headerConfig.babyName == "小豆子")
        #expect(state.headerConfig.birthDate == Date(timeIntervalSince1970: 0))
    }

    @Test("updateFrom nil returns placeholder")
    func testUpdateFromNil() {
        let state = ActiveBabyState()
        state.headerConfig = HomeHeaderConfig(babyName: "旧名字", birthDate: .now)

        state.updateFrom(nil as BabyProfile?)

        #expect(state.headerConfig.babyName == HomeHeaderConfig.placeholder.babyName)
    }

    @Test("successive updates reflect latest data")
    func testSuccessiveUpdates() async throws {
        let env = try makeTestEnvironment(now: .now)
        let state = ActiveBabyState()
        let repo = env.makeBabyRepository(activeBabyState: state)
        repo.createDefaultIfNeeded()
        state.updateFrom(repo.activeBaby)

        repo.updateName("A")
        #expect(state.headerConfig.babyName == "A")

        repo.updateName("B")
        #expect(state.headerConfig.babyName == "B")
    }
}
