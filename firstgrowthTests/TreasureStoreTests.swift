import Foundation
import XCTest
@testable import firstgrowth

@MainActor
final class TreasureStoreTests: XCTestCase {
    func testShowsMonthHintOnlyOnFirstEligibleLoad() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let calendar = Calendar(identifier: .gregorian)

        _ = try environment.treasureRepository.createMemoryEntry(
            note: "一月的一条。",
            imageLocalPaths: [],
            isMilestone: false,
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            birthDate: HomeHeaderConfig.placeholder.birthDate
        )
        _ = try environment.treasureRepository.createMemoryEntry(
            note: "三月的一条。",
            imageLocalPaths: [],
            isMilestone: false,
            createdAt: environment.now.value,
            birthDate: HomeHeaderConfig.placeholder.birthDate
        )

        let hintStore = TreasureMonthHintStore(defaults: environment.defaults, storageKey: "treasure.hint.once")
        let firstStore = makeTreasureStore(environment: environment, monthHintStore: hintStore)
        firstStore.onAppear()

        XCTAssertEqual(firstStore.viewState.monthScrubberState, .onboardingNudge)

        let secondStore = makeTreasureStore(environment: environment, monthHintStore: hintStore)
        secondStore.onAppear()

        XCTAssertNotEqual(secondStore.viewState.monthScrubberState, .onboardingNudge)
        XCTAssertTrue(environment.defaults.bool(forKey: "treasure.hint.once"))
        _ = calendar
    }

    func testTimelineLoadsMixedItemsByDefault() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = makeTreasureStore(environment: environment)
        let weekStart = Calendar(identifier: .gregorian).date(
            from: Calendar(identifier: .gregorian).dateComponents([.yearForWeekOfYear, .weekOfYear], from: environment.now.value)
        )!

        _ = try environment.treasureRepository.createMemoryEntry(
            note: "会站一下了。",
            imageLocalPaths: [],
            isMilestone: true,
            createdAt: environment.now.value,
            birthDate: HomeHeaderConfig.placeholder.birthDate
        )
        try environment.treasureRepository.syncWeeklyLetter(
            for: weekStart,
            composer: WeeklyLetterComposer(calendar: Calendar(identifier: .gregorian)),
            generatedAt: environment.now.value
        )

        store.onAppear()
        XCTAssertTrue(store.viewState.timelineItems.contains(where: { $0.type == .milestone }))
        XCTAssertTrue(store.viewState.timelineItems.contains(where: \.isWeeklyLetter))
        XCTAssertFalse(store.viewState.timelineItems.isEmpty)
    }

    func testMilestoneOnlyDraftRequestsDiscardConfirmation() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = makeTreasureStore(environment: environment)

        store.onAppear()
        store.handle(.tapAddToday)
        store.handle(.toggleMilestone)
        store.handle(.dismissCompose)

        XCTAssertEqual(store.viewState.composeState, .confirmingDiscard)
        XCTAssertTrue(store.shouldShowDiscardConfirmation)
    }

    func testSaveAndUndoRefreshesTimelineAndLetters() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = makeTreasureStore(environment: environment)

        store.onAppear()
        store.handle(.tapAddToday)
        store.handle(.updateNote("睡前多看了一会儿窗外。"))
        store.handle(.saveCompose)

        XCTAssertEqual(try environment.treasureRepository.fetchMemoryEntries().count, 1)
        XCTAssertEqual(try environment.treasureRepository.fetchWeeklyLetters().count, 1)
        XCTAssertEqual(store.viewState.undoToast?.message, "已留住今天")
        XCTAssertFalse(store.viewState.timelineItems.isEmpty)

        store.handle(.undoLastEntry)

        XCTAssertTrue(try environment.treasureRepository.fetchMemoryEntries().isEmpty)
        XCTAssertTrue(try environment.treasureRepository.fetchWeeklyLetters().isEmpty)
        XCTAssertEqual(store.viewState.dataState, .empty)
        XCTAssertNil(store.viewState.undoToast)
    }

    func testFloatingAddButtonStartsVisible() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = makeTreasureStore(environment: environment)

        store.onAppear()

        XCTAssertTrue(store.viewState.isFloatingAddButtonVisible)
    }

    func testScrollingDownHidesFloatingAddButton() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = makeTreasureStore(environment: environment)

        store.onAppear()
        store.handle(.didScroll(offset: 0, timestamp: 0))
        store.handle(.didScroll(offset: -120, timestamp: 1))

        XCTAssertFalse(store.viewState.isFloatingAddButtonVisible)
    }

    func testScrollingUpShowsFloatingAddButton() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = makeTreasureStore(environment: environment)

        store.onAppear()
        store.handle(.didScroll(offset: 0, timestamp: 0))
        store.handle(.didScroll(offset: -120, timestamp: 1))
        store.handle(.didScroll(offset: -80, timestamp: 2))

        XCTAssertTrue(store.viewState.isFloatingAddButtonVisible)
    }

    func testScrollingFartherFromTopHidesFloatingAddButtonForPositiveOffsets() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = makeTreasureStore(environment: environment)

        store.onAppear()
        store.handle(.didScroll(offset: 0, timestamp: 0))
        store.handle(.didScroll(offset: 120, timestamp: 1))

        XCTAssertFalse(store.viewState.isFloatingAddButtonVisible)
    }

    func testScrollingCloserToTopShowsFloatingAddButtonForPositiveOffsets() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = makeTreasureStore(environment: environment)

        store.onAppear()
        store.handle(.didScroll(offset: 0, timestamp: 0))
        store.handle(.didScroll(offset: 120, timestamp: 1))
        store.handle(.didScroll(offset: 80, timestamp: 2))

        XCTAssertTrue(store.viewState.isFloatingAddButtonVisible)
    }

    func testStoppedScrollShowsFloatingAddButtonAgain() async throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = makeTreasureStore(environment: environment)

        store.onAppear()
        store.handle(.didScroll(offset: 0, timestamp: 0))
        store.handle(.didScroll(offset: -120, timestamp: 1))
        XCTAssertFalse(store.viewState.isFloatingAddButtonVisible)

        try await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(store.viewState.isFloatingAddButtonVisible)
    }

    func testActiveScrollInteractionKeepsFloatingAddButtonHidden() async throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = makeTreasureStore(environment: environment)

        store.onAppear()
        store.handle(.beginScrollInteraction)
        store.handle(.didScroll(offset: 0, timestamp: 0))
        store.handle(.didScroll(offset: -120, timestamp: 1))

        XCTAssertFalse(store.viewState.isFloatingAddButtonVisible)

        try await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(store.viewState.isFloatingAddButtonVisible)

        store.handle(.endScrollInteraction)
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(store.viewState.isFloatingAddButtonVisible)
    }

    func testReturningToTopShowsFloatingAddButton() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = makeTreasureStore(environment: environment)

        store.onAppear()
        store.handle(.didScroll(offset: 0, timestamp: 0))
        store.handle(.didScroll(offset: -120, timestamp: 1))
        store.handle(.didScroll(offset: -12, timestamp: 2))

        XCTAssertTrue(store.viewState.isFloatingAddButtonVisible)
    }

    func testDiscardingDraftRemovesAllDraftImages() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        var removedPaths: [String] = []
        let store = makeTreasureStore(environment: environment, imageRemover: { removedPaths.append(contentsOf: $0) })

        store.onAppear()
        store.handle(.tapAddToday)
        store.handle(.appendImagePaths(["/tmp/a.jpg", "/tmp/b.jpg"]))
        store.handle(.dismissCompose)

        XCTAssertEqual(store.viewState.composeState, .confirmingDiscard)

        store.handle(.confirmDiscard)

        XCTAssertEqual(removedPaths, ["/tmp/a.jpg", "/tmp/b.jpg"])
        XCTAssertTrue(store.viewState.composeDraft.imageLocalPaths.isEmpty)
        XCTAssertEqual(store.viewState.composeState, .closed)
    }

    func testUndoClosesWeeklyLetterWhenAffectedCardDisappears() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = makeTreasureStore(environment: environment)

        store.onAppear()
        store.handle(.tapAddToday)
        store.handle(.updateNote("第一次把手搭在床边。"))
        store.handle(.toggleMilestone)
        store.handle(.saveCompose)

        guard let letter = store.viewState.timelineItems.first(where: \.canOpenWeeklyLetter) else {
            return XCTFail("Expected openable weekly letter in timeline")
        }

        store.handle(.tapWeeklyLetter(letter.id))
        XCTAssertEqual(store.viewState.selectedWeeklyLetter?.id, letter.id)

        store.handle(.undoLastEntry)

        XCTAssertNil(store.viewState.selectedWeeklyLetter)
        XCTAssertEqual(store.viewState.weeklyLetterViewState, .collapsed)
        XCTAssertTrue(try environment.treasureRepository.fetchWeeklyLetters().isEmpty)
    }
}
