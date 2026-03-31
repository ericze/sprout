import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class HomeStore {
    var routeState = HomeRouteState()
    var viewState = HomeViewState()
    var foodDraft = FoodDraftState()
    var milkDraft = FeedingDraftState()
    var isShowingFoodDiscardConfirmation = false

    var headerConfig: HomeHeaderConfig

    @ObservationIgnored private var recordRepository: RecordRepository?
    @ObservationIgnored private let formatter: TimelineContentFormatter
    @ObservationIgnored private let localizationService: LocalizationService
    @ObservationIgnored private let sleepSessionRepository: SleepSessionRepository
    @ObservationIgnored private let foodTagCatalog: FoodTagCatalog
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let dateProvider: () -> Date
    @ObservationIgnored private let historyPageSize: Int
    @ObservationIgnored private var loadedHistoryCount = 0
    @ObservationIgnored private var undoDismissTask: Task<Void, Never>?
    init(
        headerConfig: HomeHeaderConfig,
        recordRepository: RecordRepository? = nil,
        formatter: TimelineContentFormatter? = nil,
        localizationService: LocalizationService = .current,
        sleepSessionRepository: SleepSessionRepository = SleepSessionRepository(),
        calendar: Calendar = .current,
        historyPageSize: Int = 20,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.headerConfig = headerConfig
        self.recordRepository = recordRepository
        self.localizationService = localizationService
        self.formatter = formatter ?? TimelineContentFormatter(localizationService: localizationService)
        self.foodTagCatalog = FoodTagCatalog(language: localizationService.language)
        self.sleepSessionRepository = sleepSessionRepository
        self.calendar = calendar
        self.historyPageSize = historyPageSize
        self.dateProvider = dateProvider
    }

    deinit {
        undoDismissTask?.cancel()
    }
}
extension HomeStore {
    var timelineItems: [TimelineDisplayItem] {
        viewState.timelineItems
    }

    var recentFoodTags: [String] {
        viewState.recentFoodTags
    }

    var suggestedFoodTags: [String] {
        foodTagCatalog.commonTags.filter { !recentFoodTags.contains($0) }
    }

    var isFoodSaveEnabled: Bool {
        foodDraft.hasContent
    }

    var shouldDisableFoodInteractiveDismiss: Bool {
        routeState.activeSheet == .food && foodDraft.hasContent
    }

    var canRevealSidebarFromRoot: Bool {
        routeState.activeSheet == nil && !isShowingFoodDiscardConfirmation
    }

    func configure(modelContext: ModelContext) {
        guard recordRepository == nil else { return }
        recordRepository = RecordRepository(modelContext: modelContext, calendar: calendar)
    }

    func updateHeaderConfig(_ config: HomeHeaderConfig) {
        headerConfig = config
    }

    func onAppear() {
        handle(.onAppear)
    }

    func feedingSubmitButtonTitle(now: Date) -> String {
        formatter.feedingSubmitButtonTitle(
            totalNursingSeconds: milkDraft.totalNursingSeconds(now: now),
            bottleAmountMl: milkDraft.bottleAmountMl
        )
    }

    func handle(_ action: HomeAction) {
        switch action {
        case .onAppear:
            restoreOngoingSleep()
            reloadTimeline()
            refreshRecentFoodTags()
            viewState.hasLoadedInitialData = true
        case .tapMilkEntry:
            milkDraft.reset()
            routeState.activeSheet = .milk
            AppHaptics.lightImpact()
        case .tapDiaperEntry:
            routeState.activeSheet = .diaper
            AppHaptics.lightImpact()
        case .tapSleepEntry:
            handleSleepEntry()
        case .tapFoodEntry:
            resetFoodDraft(removeStoredImage: true)
            routeState.activeSheet = .food
            AppHaptics.lightImpact()
        case .tapOngoingSleep:
            guard viewState.ongoingSleep != nil else { return }
            routeState.activeSheet = .sleepControl
            AppHaptics.lightImpact()
        case .dismissSheet:
            dismissActiveSheet()
        case let .selectMilkTab(tab):
            guard milkDraft.selectedTab != tab else { return }
            milkDraft.selectTab(tab)
            AppHaptics.selection()
        case let .tapNursingSide(side):
            milkDraft.tapNursing(side: side, now: dateProvider())
            AppHaptics.mediumImpact()
        case let .selectBottlePreset(amount):
            milkDraft.selectBottlePreset(amount)
            AppHaptics.lightImpact()
        case let .adjustBottleAmount(step):
            adjustBottleAmount(step)
        case .saveFeedingRecord:
            saveFeedingRecord()
        case let .saveDiaper(subtype):
            saveDiaper(subtype: subtype)
        case .finishSleep:
            finishSleep()
        case .saveFood:
            saveFood()
        case .undoLastRecord:
            undoLastRecord()
        case .dismissUndo:
            dismissUndoToast()
        case let .loadMoreIfNeeded(recordID):
            loadMoreHistoryIfNeeded(for: recordID)
        }
    }

    func toggleFoodTag(_ tag: String) {
        if let index = foodDraft.selectedTags.firstIndex(of: tag) {
            foodDraft.selectedTags.remove(at: index)
        } else {
            foodDraft.selectedTags.append(tag)
        }
        AppHaptics.selection()
    }

    func updateFoodNote(_ note: String) {
        foodDraft.note = note
    }

    func setFoodImagePath(_ path: String?) {
        if let currentPath = foodDraft.selectedImagePath, currentPath != path {
            FoodPhotoStorage.removeImage(at: currentPath)
        }
        foodDraft.selectedImagePath = path
    }

    func removeFoodImage() {
        FoodPhotoStorage.removeImage(at: foodDraft.selectedImagePath)
        foodDraft.selectedImagePath = nil
    }

    func requestFoodDismiss() {
        guard routeState.activeSheet == .food else {
            routeState.activeSheet = nil
            return
        }

        if foodDraft.hasContent {
            isShowingFoodDiscardConfirmation = true
        } else {
            routeState.activeSheet = nil
        }
    }

    func discardFoodDraft() {
        resetFoodDraft(removeStoredImage: true)
        isShowingFoodDiscardConfirmation = false
        routeState.activeSheet = nil
    }

    func keepEditingFoodDraft() {
        isShowingFoodDiscardConfirmation = false
    }

    private func handleSleepEntry() {
        if viewState.ongoingSleep != nil {
            routeState.activeSheet = .sleepControl
            AppHaptics.lightImpact()
            return
        }

        let session = sleepSessionRepository.startSession(startedAt: dateProvider())
        viewState.ongoingSleep = session
        routeState.activeSheet = nil
        AppHaptics.mediumImpact()
    }

    private func dismissActiveSheet() {
        switch routeState.activeSheet {
        case .milk:
            milkDraft.reset()
            routeState.activeSheet = nil
        case .food:
            requestFoodDismiss()
        default:
            routeState.activeSheet = nil
        }
    }

    private func adjustBottleAmount(_ step: Int) {
        let previousAmount = milkDraft.bottleAmountMl
        if step > 0 {
            milkDraft.increaseBottle()
        } else if step < 0 {
            milkDraft.decreaseBottle()
        }

        if milkDraft.bottleAmountMl != previousAmount {
            AppHaptics.softImpact()
        }
    }

    private func saveFeedingRecord() {
        guard let recordRepository else { return }

        let now = dateProvider()
        milkDraft.pauseActiveSide(now: now)

        let leftSeconds = milkDraft.leftAccumulatedSeconds
        let rightSeconds = milkDraft.rightAccumulatedSeconds
        let bottleAmountMl = milkDraft.bottleAmountMl

        guard leftSeconds > 0 || rightSeconds > 0 || bottleAmountMl > 0 else { return }

        do {
            let record = try recordRepository.createFeedingRecord(
                leftSeconds: leftSeconds,
                rightSeconds: rightSeconds,
                bottleAmountMl: bottleAmountMl,
                at: now
            )
            let title = formatter.makeDisplayItem(from: record)?.title ?? formatter.defaultFeedingTitle()
            milkDraft.reset()
            routeState.activeSheet = nil
            integrateCreatedRecord(record, message: formatter.savedRecordMessage(title: title))
            AppHaptics.mediumImpact()
        } catch {
            assertionFailure("Feeding save failed: \(error)")
        }
    }

    private func saveDiaper(subtype: DiaperSubtype) {
        guard let recordRepository else { return }

        do {
            let record = try recordRepository.createDiaperRecord(subtype: subtype, at: dateProvider())
            routeState.activeSheet = nil
            integrateCreatedRecord(record, message: formatter.savedRecordMessage(title: formatter.formatDiaperTitle(subType: subtype.rawValue)))
            AppHaptics.mediumImpact()
        } catch {
            assertionFailure("Diaper save failed: \(error)")
        }
    }

    private func finishSleep() {
        guard let recordRepository, let session = viewState.ongoingSleep else { return }

        do {
            _ = sleepSessionRepository.endSession()
            viewState.ongoingSleep = nil
            let record = try recordRepository.createSleepRecord(
                startedAt: session.startedAt,
                endedAt: dateProvider()
            )
            routeState.activeSheet = nil
            integrateCreatedRecord(record, message: formatter.endedSleepMessage())
            AppHaptics.success()
        } catch {
            assertionFailure("Sleep finish failed: \(error)")
        }
    }

    private func saveFood() {
        guard let recordRepository, isFoodSaveEnabled else { return }

        do {
            let record = try recordRepository.createFoodRecord(
                tags: foodDraft.selectedTags,
                note: foodDraft.note,
                imageURL: foodDraft.selectedImagePath,
                at: dateProvider()
            )
            resetFoodDraft(removeStoredImage: false)
            routeState.activeSheet = nil
            integrateCreatedRecord(record, message: formatter.savedFoodMessage())
            AppHaptics.mediumImpact()
        } catch {
            assertionFailure("Food save failed: \(error)")
        }
    }

    private func undoLastRecord() {
        guard let recordRepository, let undoToast = viewState.undoToast else { return }

        do {
            try recordRepository.deleteRecord(id: undoToast.recordID)
            dismissUndoToast()
            reloadTimeline()
            refreshRecentFoodTags()
        } catch {
            assertionFailure("Undo failed: \(error)")
        }
    }

    private func integrateCreatedRecord(_ record: RecordItem, message: String) {
        let startOfDay = calendar.startOfDay(for: dateProvider())
        if record.timestamp < startOfDay {
            loadedHistoryCount = max(loadedHistoryCount, 1)
        }

        reloadTimeline()
        refreshRecentFoodTags()
        showUndoToast(recordID: record.id, message: message)
    }

    private func reloadTimeline() {
        reloadTodayRecords()
        reloadHistoryRecords()
    }

    private func reloadTodayRecords() {
        guard let recordRepository else { return }

        do {
            viewState.todayDisplayItems = formatter.makeDisplayItems(
                from: try recordRepository.fetchTodayRecords(referenceDate: dateProvider())
            )
        } catch {
            assertionFailure("Reload today records failed: \(error)")
        }
    }

    private func reloadHistoryRecords() {
        guard let recordRepository else { return }

        guard loadedHistoryCount > 0 else {
            viewState.historyDisplayItems = []
            viewState.hasMoreHistory = true
            return
        }

        do {
            let startOfDay = calendar.startOfDay(for: dateProvider())
            let records = try recordRepository.fetchHistory(before: startOfDay, limit: loadedHistoryCount + 1)
            viewState.historyDisplayItems = formatter.makeDisplayItems(from: Array(records.prefix(loadedHistoryCount)))
            viewState.hasMoreHistory = records.count > loadedHistoryCount
        } catch {
            assertionFailure("Reload history failed: \(error)")
        }
    }

    private func refreshRecentFoodTags() {
        guard let recordRepository else { return }

        do {
            viewState.recentFoodTags = try recordRepository.fetchRecentFoodTags()
        } catch {
            assertionFailure("Refresh recent food tags failed: \(error)")
        }
    }

    private func restoreOngoingSleep() {
        viewState.ongoingSleep = sleepSessionRepository.loadActiveSession()
    }

    private func loadMoreHistoryIfNeeded(for recordID: UUID) {
        guard
            !viewState.isLoadingHistory,
            viewState.hasMoreHistory,
            timelineItems.last?.recordID == recordID,
            let recordRepository
        else {
            return
        }

        viewState.isLoadingHistory = true
        defer { viewState.isLoadingHistory = false }

        do {
            let cutoff = viewState.historyDisplayItems.last?.timestamp ?? calendar.startOfDay(for: dateProvider())
            let records = try recordRepository.fetchHistory(before: cutoff, limit: historyPageSize)
            let newItems = formatter.makeDisplayItems(from: records)
            viewState.historyDisplayItems.append(contentsOf: newItems)
            loadedHistoryCount = viewState.historyDisplayItems.count
            viewState.hasMoreHistory = records.count == historyPageSize
        } catch {
            assertionFailure("Load more history failed: \(error)")
        }
    }

    private func resetFoodDraft(removeStoredImage: Bool) {
        if removeStoredImage {
            FoodPhotoStorage.removeImage(at: foodDraft.selectedImagePath)
        }
        foodDraft = FoodDraftState()
    }

    private func showUndoToast(recordID: UUID, message: String) {
        undoDismissTask?.cancel()
        viewState.undoToast = UndoToastState(recordID: recordID, message: message)

        undoDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            self.viewState.undoToast = nil
        }
    }

    private func dismissUndoToast() {
        undoDismissTask?.cancel()
        undoDismissTask = nil
        viewState.undoToast = nil
    }
}
