import XCTest
@testable import firstgrowth

@MainActor
final class HomeStoreTests: XCTestCase {
    func testBottleOnlyFeedingSaveAndUndo() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let store = environment.store

        store.handle(.tapMilkEntry)
        store.handle(.selectMilkTab(.bottle))
        store.handle(.selectBottlePreset(120))
        store.handle(.saveFeedingRecord)

        let records = try environment.recordRepository.fetchAllRecords()

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.bottleAmountMl, 120)
        XCTAssertEqual(records.first?.leftNursingSeconds, 0)
        XCTAssertEqual(records.first?.rightNursingSeconds, 0)
        XCTAssertEqual(store.viewState.todayDisplayItems.first?.title, "120ml 瓶喂")
        XCTAssertEqual(store.viewState.undoToast?.message, "已记录120ml 瓶喂")

        store.handle(.undoLastRecord)

        XCTAssertTrue(try environment.recordRepository.fetchAllRecords().isEmpty)
        XCTAssertTrue(store.timelineItems.isEmpty)
        XCTAssertNil(store.viewState.undoToast)
    }

    func testMixedFeedingPersistsAcrossTabsAndSavesAsSingleRecord() throws {
        let startDate = Date(timeIntervalSince1970: 1_710_000_000)
        let environment = try makeTestEnvironment(now: startDate)
        let store = environment.store

        store.handle(.tapMilkEntry)
        store.handle(.tapNursingSide(.left))

        environment.now.value = startDate.addingTimeInterval(9 * 60)
        store.handle(.selectMilkTab(.bottle))
        XCTAssertEqual(store.milkDraft.displayedSeconds(for: .left, now: environment.now.value), 9 * 60)

        environment.now.value = startDate.addingTimeInterval(10 * 60)
        XCTAssertEqual(store.milkDraft.displayedSeconds(for: .left, now: environment.now.value), 10 * 60)

        store.handle(.selectBottlePreset(60))
        store.handle(.selectMilkTab(.nursing))
        store.handle(.tapNursingSide(.right))

        XCTAssertEqual(store.milkDraft.leftAccumulatedSeconds, 10 * 60)
        XCTAssertEqual(store.milkDraft.activeSide, .right)

        environment.now.value = startDate.addingTimeInterval(15 * 60)
        store.handle(.saveFeedingRecord)

        let records = try environment.recordRepository.fetchAllRecords()
        let record = try XCTUnwrap(records.first)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(record.leftNursingSeconds, 10 * 60)
        XCTAssertEqual(record.rightNursingSeconds, 5 * 60)
        XCTAssertEqual(record.bottleAmountMl, 60)
        XCTAssertEqual(store.viewState.todayDisplayItems.first?.title, "亲喂 15分钟 + 60ml 瓶喂")
        XCTAssertEqual(store.viewState.todayDisplayItems.first?.subtitle, "左 10m · 右 5m")
        XCTAssertEqual(store.viewState.undoToast?.message, "已记录亲喂 15分钟 + 60ml 瓶喂")
    }

    func testMilkDismissResetsDraftAndReopensClean() throws {
        let startDate = Date(timeIntervalSince1970: 1_710_000_000)
        let environment = try makeTestEnvironment(now: startDate)
        let store = environment.store

        store.handle(.tapMilkEntry)
        store.handle(.selectMilkTab(.bottle))
        store.handle(.selectBottlePreset(90))
        store.handle(.selectMilkTab(.nursing))
        store.handle(.tapNursingSide(.left))

        environment.now.value = startDate.addingTimeInterval(2 * 60)
        store.handle(.dismissSheet)

        XCTAssertNil(store.routeState.activeSheet)
        XCTAssertEqual(store.milkDraft.selectedTab, .nursing)
        XCTAssertEqual(store.milkDraft.bottleAmountMl, 0)
        XCTAssertEqual(store.milkDraft.leftAccumulatedSeconds, 0)
        XCTAssertEqual(store.milkDraft.rightAccumulatedSeconds, 0)
        XCTAssertNil(store.milkDraft.activeSide)
        XCTAssertNil(store.milkDraft.activeStartDate)

        store.handle(.tapMilkEntry)
        XCTAssertEqual(store.milkDraft.selectedTab, .nursing)
        XCTAssertEqual(store.milkDraft.bottleAmountMl, 0)
        XCTAssertEqual(store.milkDraft.leftAccumulatedSeconds, 0)
    }

    func testSleepSessionRestoresAndFinishes() throws {
        let initialDate = Date(timeIntervalSince1970: 1_710_000_000)
        let environment = try makeTestEnvironment(now: initialDate)

        environment.store.handle(.tapSleepEntry)
        XCTAssertNotNil(environment.store.viewState.ongoingSleep)

        let restoredStore = HomeStore(
            headerConfig: .placeholder,
            recordRepository: environment.recordRepository,
            formatter: TimelineContentFormatter(),
            sleepSessionRepository: SleepSessionRepository(defaults: environment.defaults, storageKey: "active_sleep_session_test"),
            calendar: Calendar(identifier: .gregorian),
            historyPageSize: 20,
            dateProvider: { environment.now.value }
        )

        restoredStore.onAppear()
        XCTAssertNotNil(restoredStore.viewState.ongoingSleep)

        environment.now.value = initialDate.addingTimeInterval(90 * 60)
        restoredStore.handle(.finishSleep)

        XCTAssertNil(restoredStore.viewState.ongoingSleep)
        XCTAssertEqual(try environment.recordRepository.fetchAllRecords().count, 1)
        XCTAssertEqual(restoredStore.viewState.todayDisplayItems.first?.title, "睡了 1小时30分")

        restoredStore.handle(.undoLastRecord)
        XCTAssertTrue(try environment.recordRepository.fetchAllRecords().isEmpty)
        XCTAssertNil(restoredStore.viewState.ongoingSleep)
    }

    func testFoodDraftDismissConfirmation() throws {
        let environment = try makeTestEnvironment(now: .now)
        let store = environment.store

        store.handle(.tapFoodEntry)
        XCTAssertFalse(store.isFoodSaveEnabled)

        store.updateFoodNote("今天一直在扔勺子")
        XCTAssertTrue(store.isFoodSaveEnabled)

        store.requestFoodDismiss()
        XCTAssertTrue(store.isShowingFoodDiscardConfirmation)

        store.discardFoodDraft()
        XCTAssertFalse(store.foodDraft.hasContent)
        XCTAssertNil(store.routeState.activeSheet)
    }

    func testHistoryPaginationLoadsOlderRecords() throws {
        let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)
        let environment = try makeTestEnvironment(now: referenceDate)
        let repository = environment.recordRepository

        try repository.createFeedingRecord(leftSeconds: 0, rightSeconds: 0, bottleAmountMl: 120, at: referenceDate)
        for offset in 1...25 {
            let pastDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: -offset, to: referenceDate)!
            try repository.createFeedingRecord(leftSeconds: 0, rightSeconds: 0, bottleAmountMl: 90 + offset, at: pastDate)
        }

        environment.store.onAppear()

        XCTAssertEqual(environment.store.viewState.todayDisplayItems.count, 1)
        XCTAssertTrue(environment.store.viewState.historyDisplayItems.isEmpty)

        if let lastToday = environment.store.viewState.todayDisplayItems.last {
            environment.store.handle(.loadMoreIfNeeded(lastToday.recordID))
        }

        XCTAssertEqual(environment.store.viewState.historyDisplayItems.count, 20)
        XCTAssertTrue(environment.store.viewState.hasMoreHistory)

        if let lastHistory = environment.store.viewState.historyDisplayItems.last {
            environment.store.handle(.loadMoreIfNeeded(lastHistory.recordID))
        }

        XCTAssertEqual(environment.store.viewState.historyDisplayItems.count, 25)
        XCTAssertFalse(environment.store.viewState.hasMoreHistory)
    }
}
