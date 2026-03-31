import Testing
@testable import sprout

@MainActor
struct HomeHeaderConfigTests {

    @Test("from baby creates config with baby data")
    func testFromBaby() async throws {
        let env = try makeTestEnvironment(now: .now)
        let repo = env.makeBabyRepository()
        repo.createDefaultIfNeeded()
        repo.updateName("小花生")
        let config = HomeHeaderConfig.from(repo.activeBaby)
        #expect(config.babyName == "小花生")
    }

    @Test("from nil returns placeholder")
    func testFromNil() {
        let config = HomeHeaderConfig.from(nil as BabyProfile?)
        #expect(config.babyName == HomeHeaderConfig.placeholder.babyName)
    }
}
