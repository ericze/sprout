import Foundation
import Observation
import OSLog
import SwiftData

@MainActor
@Observable
final class HomeStore {
    var routeState = HomeRouteState()
    var viewState = HomeViewState()
    var foodDraft = FoodDraftState()
    var foodDraftTimestamp = Date()
    var milkDraft = FeedingDraftState()
    var diaperDraft = DiaperDraftState()
    var sleepEditDraft = SleepRecordEditDraft(startTime: Date(), endTime: Date())
    var isShowingFoodDiscardConfirmation = false

    var headerConfig: HomeHeaderConfig

    @ObservationIgnored private var recordRepository: RecordRepository?
    @ObservationIgnored private let formatter: TimelineContentFormatter
    @ObservationIgnored private let localizationService: LocalizationService
    @ObservationIgnored private let localeFormatter: LocaleFormatter
    @ObservationIgnored private let sleepSessionRepository: SleepSessionRepository
    @ObservationIgnored private let foodTagCatalog: FoodTagCatalog
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let dateProvider: () -> Date
    @ObservationIgnored private let historyPageSize: Int
    @ObservationIgnored private var foodEditorSession = FoodEditorSession.create(at: Date())
    @ObservationIgnored private var loadedHistoryCount = 0
    @ObservationIgnored private var undoDismissTask: Task<Void, Never>?
    @ObservationIgnored private var messageDismissTask: Task<Void, Never>?
    @ObservationIgnored private var aiService: FoodAIAssistService?
    @ObservationIgnored private var aiSuggestTask: Task<Void, Never>?
    init(
        headerConfig: HomeHeaderConfig,
        recordRepository: RecordRepository? = nil,
        formatter: TimelineContentFormatter? = nil,
        localizationService: LocalizationService? = nil,
        sleepSessionRepository: SleepSessionRepository = SleepSessionRepository(),
        calendar: Calendar = .current,
        historyPageSize: Int = 20,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        let resolvedLocalizationService = localizationService ?? .current
        self.headerConfig = headerConfig
        self.recordRepository = recordRepository
        self.localizationService = resolvedLocalizationService
        self.formatter = formatter ?? TimelineContentFormatter(localizationService: resolvedLocalizationService)
        self.localeFormatter = LocaleFormatter(
            locale: resolvedLocalizationService.locale,
            calendar: calendar,
            localizationService: resolvedLocalizationService
        )
        self.foodTagCatalog = FoodTagCatalog(language: resolvedLocalizationService.language)
        self.sleepSessionRepository = sleepSessionRepository
        self.calendar = calendar
        self.historyPageSize = historyPageSize
        self.dateProvider = dateProvider

        let initialDraftDate = dateProvider()
        self.foodDraftTimestamp = initialDraftDate
        self.milkDraft = FeedingDraftState(recordedAt: initialDraftDate)
        self.diaperDraft = DiaperDraftState(recordedAt: initialDraftDate)
        self.foodEditorSession = FoodEditorSession.create(at: initialDraftDate)
        self.sleepEditDraft = SleepRecordEditDraft(startTime: initialDraftDate, endTime: initialDraftDate)
    }

    deinit {
        undoDismissTask?.cancel()
        messageDismissTask?.cancel()
        aiSuggestTask?.cancel()
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

    var customFoodTags: [String] {
        foodDraft.selectedTags.filter { tag in
            !containsFoodTag(tag, in: recentFoodTags) &&
                !containsFoodTag(tag, in: foodTagCatalog.commonTags)
        }
    }

    var allSuggestedFoodTags: [String] {
        uniqueFoodTags(from: recentFoodTags + foodTagCatalog.allKnownTags)
    }

    var foodFirstTasteHint: FoodFirstTasteHint? {
        guard !viewState.firstTasteFoodTags.isEmpty else { return nil }

        return FoodFirstTasteHint(
            tags: viewState.firstTasteFoodTags,
            message: makeFirstTasteHintMessage(tags: viewState.firstTasteFoodTags)
        )
    }

    var isFoodSaveEnabled: Bool {
        guard foodDraft.hasContent else { return false }

        if isEditingFoodRecord {
            return hasUnsavedFoodChanges
        }

        return true
    }

    var hasUnsavedFoodChanges: Bool {
        if isEditingFoodRecord {
            return foodDraftSnapshot != foodEditorSession.baseline
        }

        guard foodDraft.hasContent else { return false }
        return foodDraftSnapshot != foodEditorSession.baseline
    }

    var shouldDisableFoodInteractiveDismiss: Bool {
        routeState.activeSheet?.isFoodRecordEditor == true && hasUnsavedFoodChanges
    }

    var canRevealSidebarFromRoot: Bool {
        routeState.activeSheet == nil &&
            routeState.recordDeleteState.summary == nil &&
            !viewState.recordMutationState.isInFlight &&
            viewState.recordInteractionFocusState == .timelineIdle &&
            !isShowingFoodDiscardConfirmation
    }

    var activeRecordEditorRoute: RecordEditorRouteState? {
        routeState.recordEditorRoute
    }

    var activeDeleteSummary: RecordDeleteSummary? {
        routeState.recordDeleteState.summary
    }

    var activeUndoAction: HomeAction {
        switch viewState.recordFeedbackState {
        case .undoDelete:
            .undoDeletedRecord
        case .undoCreate:
            .undoLastRecord
        case .none, .message:
            .dismissUndo
        }
    }

    var foodSheetTitle: String {
        isEditingFoodRecord
            ? editRecordSheetTitle()
            : String(localized: "home.sheet.food.title")
    }

    var foodPrimaryActionTitle: String {
        isEditingFoodRecord
            ? saveRecordChangesTitle()
            : String(localized: "common.done_record")
    }

    var sleepSheetTitle: String {
        editRecordSheetTitle()
    }

    var sleepPrimaryActionTitle: String {
        saveRecordChangesTitle()
    }

    var isSleepEditSaveEnabled: Bool {
        isEditingSleepRecord && sleepEditDraft.isValid && sleepEditDraft.hasChanges
    }

    var sleepEditValidationMessage: String? {
        guard isEditingSleepRecord, !sleepEditDraft.isValid else { return nil }

        return L10n.text(
            "home.sheet.sleep.edit.validation.end_before_start",
            service: localizationService,
            en: "Set the end time after the start time.",
            zh: "请把结束时间调到开始时间之后。"
        )
    }

    var isEditingFoodRecord: Bool {
        routeState.recordEditorRoute?.editorType == .food &&
            routeState.recordEditorRoute?.mode.recordID != nil
    }

    var isEditingSleepRecord: Bool {
        routeState.recordEditorRoute?.editorType == .sleep &&
            routeState.recordEditorRoute?.mode.recordID != nil
    }

    func configure(modelContext: ModelContext) {
        guard recordRepository == nil else { return }
        recordRepository = RecordRepository(modelContext: modelContext, calendar: calendar)
    }

    func configure(aiService: FoodAIAssistService) {
        self.aiService = aiService
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
            refreshKnownFoodTags()
            updateFirstTasteFoodTags()
            viewState.hasLoadedInitialData = true
        case .tapMilkEntry:
            milkDraft.reset(now: dateProvider())
            presentRecordEditor(editorType: .milk, mode: .create)
            AppHaptics.lightImpact()
        case .tapDiaperEntry:
            diaperDraft.reset(now: dateProvider())
            presentRecordEditor(editorType: .diaper, mode: .create)
            AppHaptics.lightImpact()
        case .tapSleepEntry:
            handleSleepEntry()
        case .tapFoodEntry:
            resetFoodDraft(removeStoredImage: true)
            presentRecordEditor(editorType: .food, mode: .create)
            AppHaptics.lightImpact()
        case .tapOngoingSleep:
            guard viewState.ongoingSleep != nil else { return }
            routeState.activeSheet = .sleepControl
            AppHaptics.lightImpact()
        case let .tapTimelineRecord(recordID):
            tapTimelineRecord(recordID)
        case let .longPressTimelineRecord(recordID):
            longPressTimelineRecord(recordID)
        case .releaseTimelineRecordPress:
            releaseTimelineRecordPress()
        case .dismissRecordContextMenu:
            dismissRecordContextMenu()
        case let .selectRecordContextEdit(recordID):
            selectRecordContextEdit(recordID)
        case let .selectRecordContextDelete(recordID):
            selectRecordContextDelete(recordID)
        case .cancelDeleteRecord:
            cancelDeleteRecord()
        case .confirmDeleteRecord:
            confirmDeleteRecord()
        case .dismissSheet:
            dismissActiveSheet()
        case .dismissRecordEditor:
            dismissRecordEditor()
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
        case .saveRecordEdits:
            saveRecordEdits()
        case .undoLastRecord:
            undoLastRecord()
        case .undoDeletedRecord:
            undoDeletedRecord()
        case .dismissUndo:
            dismissUndoToast()
        case .dismissMessage:
            dismissMessageToast()
        case let .loadMoreIfNeeded(recordID):
            loadMoreHistoryIfNeeded(for: recordID)
        case .tapFoodAISuggest:
            requestFoodAISuggestion()
        case .applyFoodAISuggestion:
            applyFoodAISuggestion()
        case .dismissFoodAISuggestion:
            dismissFoodAISuggestion()
        case .retryFoodAISuggestion:
            requestFoodAISuggestion()
        }
    }

    func toggleFoodTag(_ tag: String) {
        if let index = foodDraft.selectedTags.firstIndex(of: tag) {
            foodDraft.selectedTags.remove(at: index)
        } else {
            foodDraft.selectedTags.append(tag)
        }
        updateFirstTasteFoodTags()
        AppHaptics.selection()
    }

    @discardableResult
    func addFoodTag(_ rawTag: String) -> Bool {
        let normalizedTag = rawTag.trimmed
        guard !normalizedTag.isEmpty else { return false }

        let canonicalTag = canonicalFoodTag(matching: normalizedTag)
        guard !containsFoodTag(canonicalTag, in: foodDraft.selectedTags) else {
            return true
        }

        foodDraft.selectedTags.append(canonicalTag)
        updateFirstTasteFoodTags()
        AppHaptics.selection()
        return true
    }

    func foodTagSuggestions(for rawQuery: String, limit: Int = 6) -> [String] {
        let query = rawQuery.trimmed
        guard !query.isEmpty else { return [] }

        return uniqueFoodTags(
            from: (recentFoodTags + foodTagCatalog.allKnownTags).filter { tag in
                matchesFoodTagSearch(tag, query: query)
            }
        )
            .filter { tag in
                !containsFoodTag(tag, in: foodDraft.selectedTags)
            }
            .prefix(limit)
            .map { $0 }
    }

    func updateFoodNote(_ note: String) {
        foodDraft.note = note
    }

    func updateFoodTimestamp(_ timestamp: Date) {
        foodDraftTimestamp = timestamp
    }

    func setFoodImagePath(_ path: String?) {
        if let currentPath = foodDraft.selectedImagePath,
           currentPath != path,
           shouldRemoveFoodDraftImage(at: currentPath) {
            FoodPhotoStorage.removeImage(at: currentPath)
        }
        foodDraft.selectedImagePath = path
    }

    func removeFoodImage() {
        if shouldRemoveFoodDraftImage(at: foodDraft.selectedImagePath) {
            FoodPhotoStorage.removeImage(at: foodDraft.selectedImagePath)
        }
        foodDraft.selectedImagePath = nil
    }

    func updateSleepEditStartTime(_ date: Date) {
        sleepEditDraft.startTime = date
    }

    func updateSleepEditEndTime(_ date: Date) {
        sleepEditDraft.endTime = date
    }

    func requestFoodDismiss() {
        guard routeState.activeSheet?.isFoodRecordEditor == true else {
            routeState.activeSheet = nil
            viewState.recordInteractionFocusState = .timelineIdle
            return
        }

        if hasUnsavedFoodChanges {
            isShowingFoodDiscardConfirmation = true
        } else {
            dismissRecordEditor()
        }
    }

    func discardFoodDraft() {
        resetFoodDraft(removeStoredImage: true)
        isShowingFoodDiscardConfirmation = false
        dismissRecordEditor()
    }

    func keepEditingFoodDraft() {
        isShowingFoodDiscardConfirmation = false
    }

    private func handleSleepEntry() {
        if viewState.ongoingSleep != nil {
            dismissTransientFeedback()
            clearRecordDeleteState()
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
        case let .recordEditor(route) where route.editorType == .food:
            requestFoodDismiss()
        case let .recordEditor(route):
            if route.mode.recordID == nil, route.editorType == .milk {
                milkDraft.reset(now: dateProvider())
            } else if route.mode.recordID == nil, route.editorType == .diaper {
                diaperDraft.reset(now: dateProvider())
            }
            dismissRecordEditor()
        case .sleepControl:
            routeState.activeSheet = nil
        default:
            routeState.activeSheet = nil
        }
    }

    private func tapTimelineRecord(_ recordID: UUID) {
        guard canBeginTimelineRecordInteraction(recordID) else { return }
        dismissTransientFeedback()
        clearRecordDeleteState()
        viewState.recordCellInteractionState = .pressing(recordID: recordID)
        viewState.recordInteractionFocusState = .recordPressed(recordID)
    }

    private func longPressTimelineRecord(_ recordID: UUID) {
        guard canBeginTimelineRecordInteraction(recordID) else { return }
        dismissTransientFeedback()
        viewState.recordCellInteractionState = .menuTargeted(recordID: recordID)
        viewState.recordInteractionFocusState = .contextMenu(recordID)
    }

    private func releaseTimelineRecordPress() {
        guard case let .recordPressed(recordID) = viewState.recordInteractionFocusState else { return }
        viewState.recordCellInteractionState = .idle
        openRecordEditor(for: recordID)
    }

    private func dismissRecordContextMenu() {
        guard case .contextMenu = viewState.recordInteractionFocusState else { return }
        viewState.recordCellInteractionState = .idle
        viewState.recordInteractionFocusState = .timelineIdle
    }

    private func selectRecordContextEdit(_ recordID: UUID) {
        guard isContextMenuTargeting(recordID) else { return }

        viewState.recordCellInteractionState = .idle
        openRecordEditor(for: recordID)
    }

    private func selectRecordContextDelete(_ recordID: UUID) {
        guard isContextMenuTargeting(recordID) else { return }

        guard let record = fetchEditableRecord(id: recordID) else {
            resetRecordInteractionState()
            showMessageToast(missingRecordMessage())
            return
        }

        let summary = makeDeleteSummary(for: record)
        routeState.activeSheet = nil
        routeState.recordDeleteState = .confirming(summary: summary)
        viewState.recordCellInteractionState = .idle
        viewState.recordInteractionFocusState = .deleteConfirming(recordID)
    }

    private func cancelDeleteRecord() {
        clearRecordDeleteState()
        if case .deleteConfirming = viewState.recordInteractionFocusState {
            viewState.recordInteractionFocusState = .timelineIdle
        }
    }

    private func confirmDeleteRecord() {
        guard
            let recordRepository,
            case let .confirming(summary) = routeState.recordDeleteState,
            case let .deleteConfirming(focusedRecordID) = viewState.recordInteractionFocusState,
            focusedRecordID == summary.recordID
        else {
            return
        }

        guard let record = fetchEditableRecord(id: summary.recordID) else {
            clearRecordDeleteState()
            viewState.recordInteractionFocusState = .timelineIdle
            showMessageToast(missingRecordMessage())
            return
        }

        let snapshot = makeDeletedRecordSnapshot(from: record)
        viewState.recordMutationState = .deleting(recordID: summary.recordID)

        do {
            try recordRepository.deleteRecord(id: summary.recordID, strategy: .undoable)
            clearRecordDeleteState()
            viewState.recordInteractionFocusState = .timelineIdle
            viewState.recordMutationState = .idle
            reloadTimeline()
            refreshRecentFoodTags()
            refreshKnownFoodTags()
            showDeleteUndoToast(snapshot)
            AppHaptics.lightImpact()
        } catch {
            clearRecordDeleteState()
            viewState.recordInteractionFocusState = .timelineIdle
            viewState.recordMutationState = .idle
            handlePersistenceError(
                error,
                logMessage: "Delete record failed",
                userMessage: deleteFailedMessage()
            )
        }
    }

    private func dismissRecordEditor() {
        let activeRoute = routeState.recordEditorRoute
        isShowingFoodDiscardConfirmation = false
        routeState.activeSheet = nil
        if activeRoute?.editorType == .food {
            resetFoodDraft(removeStoredImage: true)
        } else if activeRoute?.editorType == .sleep {
            resetSleepEditDraft()
        }
        resetRecordInteractionState()
        if case .savingEdit = viewState.recordMutationState {
            viewState.recordMutationState = .idle
        }
    }

    private func prepareRecordEditSave() {
        guard
            let route = routeState.recordEditorRoute,
            let recordID = route.mode.recordID
        else {
            return
        }

        viewState.recordMutationState = .savingEdit(recordID: recordID)
    }

    private func saveRecordEdits() {
        guard
            let route = routeState.recordEditorRoute,
            let recordID = route.mode.recordID,
            let recordRepository,
            !viewState.recordMutationState.isInFlight
        else {
            return
        }

        switch route.editorType {
        case .food:
            guard isFoodSaveEnabled else { return }
        case .sleep:
            guard isSleepEditSaveEnabled else { return }
        case .milk:
            saveEditedFeedingRecord(recordID: recordID, using: recordRepository)
            return
        case .diaper:
            saveEditedDiaperRecord(recordID: recordID, using: recordRepository)
            return
        }

        prepareRecordEditSave()

        do {
            let updatedRecord: RecordItem

            switch route.editorType {
            case .food:
                updatedRecord = try recordRepository.updateFoodRecord(
                    id: recordID,
                    tags: uniqueFoodTags(from: foodDraft.selectedTags),
                    note: foodDraft.note,
                    imageURL: foodDraft.selectedImagePath,
                    at: foodDraftTimestamp
                )
                resetFoodDraft(removeStoredImage: false)
            case .sleep:
                updatedRecord = try recordRepository.updateSleepRecord(
                    id: recordID,
                    startedAt: sleepEditDraft.startTime,
                    endedAt: sleepEditDraft.endTime
                )
                resetSleepEditDraft()
            case .milk, .diaper:
                return
            }

            completeRecordEditSave(with: updatedRecord)
        } catch {
            failRecordEditSave(error)
        }
    }

    func completeRecordEditSave(with updatedRecord: RecordItem) {
        let startOfDay = calendar.startOfDay(for: dateProvider())
        if updatedRecord.timestamp < startOfDay {
            loadedHistoryCount = max(loadedHistoryCount, 1)
        }

        viewState.recordMutationState = .idle
        dismissRecordEditor()
        reloadTimeline()
        refreshRecentFoodTags()
        refreshKnownFoodTags()
        showMessageToast(updatedRecordMessage())
        AppHaptics.mediumImpact()
    }

    func failRecordEditSave(_ error: Error) {
        viewState.recordMutationState = .idle
        handlePersistenceError(
            error,
            logMessage: "Edit record failed",
            userMessage: editFailedMessage()
        )
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

    private func saveEditedFeedingRecord(recordID: UUID, using recordRepository: RecordRepository) {
        let now = dateProvider()
        milkDraft.pauseActiveSide(now: now)

        let leftSeconds = milkDraft.leftAccumulatedSeconds
        let rightSeconds = milkDraft.rightAccumulatedSeconds
        let bottleAmountMl = milkDraft.bottleAmountMl

        guard leftSeconds > 0 || rightSeconds > 0 || bottleAmountMl > 0 else { return }

        prepareRecordEditSave()

        do {
            let updatedRecord = try recordRepository.updateFeedingRecord(
                id: recordID,
                leftSeconds: leftSeconds,
                rightSeconds: rightSeconds,
                bottleAmountMl: bottleAmountMl,
                at: milkDraft.recordedAt
            )
            completeRecordEditSave(with: updatedRecord)
        } catch {
            failRecordEditSave(error)
        }
    }

    private func saveEditedDiaperRecord(recordID: UUID, using recordRepository: RecordRepository) {
        guard let subtype = diaperDraft.selectedSubtype else { return }

        prepareRecordEditSave()

        do {
            let updatedRecord = try recordRepository.updateDiaperRecord(
                id: recordID,
                subtype: subtype,
                at: diaperDraft.recordedAt
            )
            completeRecordEditSave(with: updatedRecord)
        } catch {
            failRecordEditSave(error)
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
            milkDraft.reset(now: now)
            dismissRecordEditor()
            integrateCreatedRecord(record, message: formatter.savedRecordMessage(title: title))
            AppHaptics.mediumImpact()
        } catch {
            handlePersistenceError(
                error,
                logMessage: "Feeding save failed",
                userMessage: L10n.text(
                    "home.error.save",
                    service: localizationService,
                    en: "Couldn't save this record. Try again.",
                    zh: "这次记录没有保存成功，请再试一次。"
                )
            )
        }
    }

    private func saveDiaper(subtype: DiaperSubtype) {
        guard let recordRepository else { return }

        do {
            let record = try recordRepository.createDiaperRecord(subtype: subtype, at: dateProvider())
            dismissRecordEditor()
            integrateCreatedRecord(record, message: formatter.savedRecordMessage(title: formatter.formatDiaperTitle(subType: subtype.rawValue)))
            AppHaptics.mediumImpact()
        } catch {
            handlePersistenceError(
                error,
                logMessage: "Diaper save failed",
                userMessage: L10n.text(
                    "home.error.save",
                    service: localizationService,
                    en: "Couldn't save this record. Try again.",
                    zh: "这次记录没有保存成功，请再试一次。"
                )
            )
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
            handlePersistenceError(
                error,
                logMessage: "Sleep finish failed",
                userMessage: L10n.text(
                    "home.error.sleep.finish",
                    service: localizationService,
                    en: "Couldn't finish sleep right now. Try again.",
                    zh: "这次没有成功结束睡眠，请再试一次。"
                )
            )
        }
    }

    private func saveFood() {
        guard let recordRepository, isFoodSaveEnabled else { return }

        do {
            let record = try recordRepository.createFoodRecord(
                tags: uniqueFoodTags(from: foodDraft.selectedTags),
                note: foodDraft.note,
                imageURL: foodDraft.selectedImagePath,
                at: foodDraftTimestamp
            )
            resetFoodDraft(removeStoredImage: false)
            dismissRecordEditor()
            integrateCreatedRecord(record, message: formatter.savedFoodMessage())
            AppHaptics.mediumImpact()
        } catch {
            handlePersistenceError(
                error,
                logMessage: "Food save failed",
                userMessage: L10n.text(
                    "home.error.save",
                    service: localizationService,
                    en: "Couldn't save this record. Try again.",
                    zh: "这次记录没有保存成功，请再试一次。"
                )
            )
        }
    }

    private func undoLastRecord() {
        guard
            let recordRepository,
            case let .undoCreate(undoToast) = viewState.recordFeedbackState
        else {
            return
        }

        do {
            try recordRepository.deleteRecord(id: undoToast.recordID)
            dismissUndoToast()
            reloadTimeline()
            refreshRecentFoodTags()
            refreshKnownFoodTags()
        } catch {
            handlePersistenceError(
                error,
                logMessage: "Home undo failed",
                userMessage: L10n.text(
                    "home.error.undo",
                    service: localizationService,
                    en: "Couldn't undo that record. Try again.",
                    zh: "这次撤销没有成功，请再试一次。"
                )
            )
        }
    }

    private func undoDeletedRecord() {
        guard
            let recordRepository,
            case let .undoDelete(snapshot) = viewState.recordFeedbackState
        else {
            return
        }

        viewState.recordMutationState = .restoringDeleted(recordID: snapshot.recordID)

        do {
            let startOfDay = calendar.startOfDay(for: dateProvider())
            if snapshot.timestamp < startOfDay {
                loadedHistoryCount = max(loadedHistoryCount, 1)
            }
            _ = try restoreDeletedRecord(from: snapshot, using: recordRepository)
            dismissUndoToast()
            viewState.recordMutationState = .idle
            reloadTimeline()
            refreshRecentFoodTags()
            refreshKnownFoodTags()
            showMessageToast(restoredRecordMessage())
            AppHaptics.mediumImpact()
        } catch {
            viewState.recordMutationState = .idle
            handlePersistenceError(
                error,
                logMessage: "Restore deleted record failed",
                userMessage: undoFailedMessage()
            )
        }
    }

    private func integrateCreatedRecord(_ record: RecordItem, message: String) {
        let startOfDay = calendar.startOfDay(for: dateProvider())
        if record.timestamp < startOfDay {
            loadedHistoryCount = max(loadedHistoryCount, 1)
        }

        reloadTimeline()
        refreshRecentFoodTags()
        refreshKnownFoodTags()
        showCreateUndoToast(recordID: record.id, message: message)
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
            handlePersistenceError(
                error,
                logMessage: "Reload today records failed",
                userMessage: L10n.text(
                    "home.error.load",
                    service: localizationService,
                    en: "Couldn't load today's records.",
                    zh: "今天的记录暂时没有加载成功。"
                )
            )
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
            handlePersistenceError(
                error,
                logMessage: "Reload history failed",
                userMessage: L10n.text(
                    "home.error.load.history",
                    service: localizationService,
                    en: "Couldn't load earlier records.",
                    zh: "更早的记录暂时没有加载成功。"
                )
            )
        }
    }

    private func refreshRecentFoodTags() {
        guard let recordRepository else { return }

        do {
            viewState.recentFoodTags = uniqueFoodTags(from: try recordRepository.fetchRecentFoodTags())
        } catch {
            handlePersistenceError(
                error,
                logMessage: "Refresh recent food tags failed",
                userMessage: L10n.text(
                    "home.error.tags",
                    service: localizationService,
                    en: "Couldn't refresh recent tags.",
                    zh: "最近的辅食标签暂时没有加载成功。"
                )
            )
        }
    }

    private func refreshKnownFoodTags() {
        guard let recordRepository else { return }

        do {
            let records = try recordRepository.fetchAllRecords()
            let tags = records
                .filter { $0.recordType == .food }
                .flatMap { $0.tags ?? [] }
                .map { foodTagCatalog.canonicalTag(for: $0) }
                .filter { !$0.isEmpty }

            viewState.knownFoodTags = uniqueFoodTags(from: tags)
            updateFirstTasteFoodTags()
        } catch {
            handlePersistenceError(
                error,
                logMessage: "Refresh known food tags failed",
                userMessage: L10n.text(
                    "home.error.tags",
                    service: localizationService,
                    en: "Couldn't refresh recent tags.",
                    zh: "最近的辅食标签暂时没有加载成功。"
                )
            )
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
            handlePersistenceError(
                error,
                logMessage: "Load more history failed",
                userMessage: L10n.text(
                    "home.error.load.history",
                    service: localizationService,
                    en: "Couldn't load earlier records.",
                    zh: "更早的记录暂时没有加载成功。"
                )
            )
        }
    }

    private func canBeginTimelineRecordInteraction(_ recordID: UUID) -> Bool {
        guard !viewState.recordMutationState.isInFlight else { return false }
        guard routeState.activeSheet == nil else { return false }
        guard routeState.recordDeleteState.summary == nil else { return false }
        guard case .timelineIdle = viewState.recordInteractionFocusState else { return false }
        return timelineItems.contains { $0.recordID == recordID }
    }

    private func presentRecordEditor(editorType: RecordEditorType, mode: RecordEditorMode) {
        dismissTransientFeedback()
        clearRecordDeleteState()
        isShowingFoodDiscardConfirmation = false
        viewState.recordCellInteractionState = .idle
        routeState.activeSheet = .recordEditor(
            RecordEditorRouteState(editorType: editorType, mode: mode)
        )

        if let recordID = mode.recordID {
            viewState.recordInteractionFocusState = .editing(recordID)
        } else {
            viewState.recordInteractionFocusState = .timelineIdle
        }
    }

    private func openRecordEditor(for recordID: UUID) {
        guard
            let record = fetchEditableRecord(id: recordID),
            let recordType = record.recordType,
            let editorType = RecordEditorType(recordType: recordType)
        else {
            resetRecordInteractionState()
            showMessageToast(missingRecordMessage())
            return
        }

        prepareEditDraft(for: record, editorType: editorType)
        presentRecordEditor(editorType: editorType, mode: .edit(recordID: recordID))
    }

    private func fetchEditableRecord(id: UUID) -> RecordItem? {
        guard let recordRepository else { return nil }

        do {
            guard
                let record = try recordRepository.fetchRecord(id: id),
                let recordType = record.recordType,
                RecordEditorType(recordType: recordType) != nil
            else {
                return nil
            }

            return record
        } catch {
            handlePersistenceError(
                error,
                logMessage: "Fetch editable record failed",
                userMessage: missingRecordMessage()
            )
            return nil
        }
    }

    private func prepareEditDraft(for record: RecordItem, editorType: RecordEditorType) {
        switch editorType {
        case .milk:
            prepareMilkDraft(for: record)
        case .diaper:
            prepareDiaperDraft(for: record)
        case .food:
            prepareFoodDraft(for: record)
        case .sleep:
            prepareSleepEditDraft(for: record)
        }
    }

    private func prepareMilkDraft(for record: RecordItem) {
        milkDraft.populate(from: record)
    }

    private func prepareDiaperDraft(for record: RecordItem) {
        diaperDraft.populate(from: record)
    }

    private func prepareFoodDraft(for record: RecordItem) {
        let imagePath = normalizedFoodImagePath(record.imageURL)
        foodDraft = FoodDraftState(
            selectedTags: uniqueFoodTags(from: record.tags ?? []),
            note: record.note?.trimmed ?? "",
            selectedImagePath: imagePath
        )
        foodDraftTimestamp = record.timestamp
        foodEditorSession = FoodEditorSession(
            baseline: foodDraftSnapshot,
            originalImagePath: imagePath
        )
        updateFirstTasteFoodTags()
    }

    private func prepareSleepEditDraft(for record: RecordItem) {
        let startTime = record.timestamp
        let duration = max(record.value ?? 0, 0)
        let endTime = startTime.addingTimeInterval(duration)
        sleepEditDraft = SleepRecordEditDraft(
            startTime: startTime,
            endTime: endTime,
            originalStartTime: startTime,
            originalEndTime: endTime
        )
    }

    private func makeDeleteSummary(for record: RecordItem) -> RecordDeleteSummary {
        let displayItem = formatter.makeDisplayItem(from: record)
        return RecordDeleteSummary(
            recordID: record.id,
            title: displayItem?.title ?? formatter.defaultFeedingTitle(),
            subtitle: displayItem?.subtitle,
            timestamp: record.timestamp,
            type: record.recordType ?? .milk
        )
    }

    private func makeDeletedRecordSnapshot(from record: RecordItem) -> DeletedRecordSnapshot {
        DeletedRecordSnapshot(
            recordID: record.id,
            timestamp: record.timestamp,
            type: record.recordType ?? .milk,
            value: record.value,
            leftNursingSeconds: record.leftNursingSeconds,
            rightNursingSeconds: record.rightNursingSeconds,
            subType: record.subType,
            imageURL: record.imageURL,
            aiSummary: record.aiSummary,
            tags: record.tags,
            note: record.note,
            message: deleteUndoMessage()
        )
    }

    private func restoreDeletedRecord(from snapshot: DeletedRecordSnapshot, using repository: RecordRepository) throws -> RecordItem {
        try repository.restoreDeletedRecord(from: recordRecoverySnapshot(from: snapshot))
    }

    private func isContextMenuTargeting(_ recordID: UUID) -> Bool {
        guard case let .contextMenu(focusedRecordID) = viewState.recordInteractionFocusState else {
            return false
        }

        return focusedRecordID == recordID
    }

    private func clearRecordDeleteState() {
        routeState.recordDeleteState = .idle
    }

    private func resetRecordInteractionState() {
        viewState.recordCellInteractionState = .idle
        viewState.recordInteractionFocusState = .timelineIdle
    }

    private func dismissTransientFeedback() {
        dismissMessageToast()
    }

    private func requestFoodAISuggestion() {
        guard let aiService, let imagePath = foodDraft.selectedImagePath else {
            viewState.foodAIState = .failed(
                L10n.text(
                    "food.ai.failed",
                    service: localizationService,
                    en: "Recognition failed, continue manually",
                    zh: "识别失败，可继续手动记录"
                )
            )
            return
        }

        viewState.foodAIState = .loading
        aiSuggestTask?.cancel()

        let allowedTags = allSuggestedFoodTags
        let knownTags = viewState.knownFoodTags
        let locale = localizationService.locale

        aiSuggestTask = Task { @MainActor [weak self] in
            do {
                let rawResult = try await aiService.suggest(
                    imageLocalPath: imagePath,
                    locale: locale,
                    allowedTags: allowedTags,
                    knownFoodTags: knownTags
                )
                guard !Task.isCancelled else { return }
                let canonicalized = rawResult.canonicalized(
                    with: self?.foodTagCatalog ?? FoodTagCatalog(language: .english),
                    allowedTags: allowedTags
                )
                self?.viewState.foodAIState = .suggestion(canonicalized)
            } catch {
                guard !Task.isCancelled else { return }
                self?.viewState.foodAIState = .failed(
                    L10n.text(
                        "food.ai.failed",
                        service: self?.localizationService ?? .current,
                        en: "Recognition failed, continue manually",
                        zh: "识别失败，可继续手动记录"
                    )
                )
            }
        }
    }

    private func applyFoodAISuggestion() {
        guard case let .suggestion(result) = viewState.foodAIState else { return }

        for candidate in result.candidateTags {
            let canonicalTag = canonicalFoodTag(matching: candidate.tag)
            guard !canonicalTag.isEmpty else { continue }
            guard !containsFoodTag(canonicalTag, in: foodDraft.selectedTags) else { continue }
            foodDraft.selectedTags.append(canonicalTag)
        }

        if let noteSuggestion = result.noteSuggestion, !noteSuggestion.isEmpty, foodDraft.note.trimmed.isEmpty {
            foodDraft.note = noteSuggestion
        }

        updateFirstTasteFoodTags()
        viewState.foodAIState = .idle
    }

    private func dismissFoodAISuggestion() {
        viewState.foodAIState = .idle
    }

    private func resetFoodDraft(removeStoredImage: Bool) {
        if removeStoredImage, shouldRemoveFoodDraftImage(at: foodDraft.selectedImagePath) {
            FoodPhotoStorage.removeImage(at: foodDraft.selectedImagePath)
        }
        foodDraft = FoodDraftState()
        foodDraftTimestamp = dateProvider()
        foodEditorSession = FoodEditorSession.create(at: foodDraftTimestamp)
        viewState.firstTasteFoodTags = []
        viewState.foodAIState = .idle
        aiSuggestTask?.cancel()
    }

    private func resetSleepEditDraft() {
        let timestamp = dateProvider()
        sleepEditDraft = SleepRecordEditDraft(startTime: timestamp, endTime: timestamp)
    }

    private var foodDraftSnapshot: FoodEditorDraftSnapshot {
        FoodEditorDraftSnapshot(
            tags: uniqueFoodTags(from: foodDraft.selectedTags),
            note: foodDraft.note.trimmed,
            imagePath: foodDraft.selectedImagePath?.trimmed.nilIfEmpty,
            timestamp: foodDraftTimestamp
        )
    }

    private func shouldRemoveFoodDraftImage(at path: String?) -> Bool {
        guard let normalizedPath = path?.trimmed.nilIfEmpty else { return false }
        return normalizedPath != foodEditorSession.originalImagePath
    }

    private func normalizedFoodImagePath(_ path: String?) -> String? {
        path?.trimmed.nilIfEmpty
    }

    private func showCreateUndoToast(recordID: UUID, message: String) {
        showUndoFeedback(.undoCreate(UndoToastState(recordID: recordID, message: message)))
    }

    private func showDeleteUndoToast(_ snapshot: DeletedRecordSnapshot) {
        showUndoFeedback(.undoDelete(snapshot))
    }

    private func showUndoFeedback(_ feedback: RecordFeedbackState) {
        guard let toast = feedback.undoToast else { return }

        messageDismissTask?.cancel()
        messageDismissTask = nil
        viewState.messageToast = nil

        undoDismissTask?.cancel()
        viewState.recordFeedbackState = feedback
        viewState.undoToast = toast

        undoDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            self.dismissUndoToast()
        }
    }

    private func dismissUndoToast() {
        undoDismissTask?.cancel()
        undoDismissTask = nil
        if case let .undoDelete(snapshot) = viewState.recordFeedbackState {
            finalizeDeletedRecordSnapshot(snapshot)
        }
        viewState.undoToast = nil
        if case .undoCreate = viewState.recordFeedbackState {
            viewState.recordFeedbackState = .none
        } else if case .undoDelete = viewState.recordFeedbackState {
            viewState.recordFeedbackState = .none
        }
    }

    private func showMessageToast(_ message: String) {
        if case let .message(currentMessage) = viewState.recordFeedbackState, currentMessage == message {
            return
        }

        dismissUndoToast()
        messageDismissTask?.cancel()
        viewState.recordFeedbackState = .message(message)
        viewState.messageToast = MessageToastState(message: message)

        messageDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            self.dismissMessageToast()
        }
    }

    private func dismissMessageToast() {
        messageDismissTask?.cancel()
        messageDismissTask = nil
        viewState.messageToast = nil
        if case .message = viewState.recordFeedbackState {
            viewState.recordFeedbackState = .none
        }
    }

    private func editRecordSheetTitle() -> String {
        L10n.text(
            "home.record.editor.title",
            service: localizationService,
            en: "Edit record",
            zh: "编辑记录"
        )
    }

    private func saveRecordChangesTitle() -> String {
        L10n.text(
            "home.record.editor.save",
            service: localizationService,
            en: "Save changes",
            zh: "保存修改"
        )
    }

    private func missingRecordMessage() -> String {
        L10n.text(
            "home.record.error.missing",
            service: localizationService,
            en: "This record no longer exists.",
            zh: "这条记录已不存在。"
        )
    }

    private func editFailedMessage() -> String {
        L10n.text(
            "home.record.error.edit_failed",
            service: localizationService,
            en: "This edit couldn't be saved. Try again.",
            zh: "这次修改没有保存成功，请再试一次。"
        )
    }

    private func deleteFailedMessage() -> String {
        L10n.text(
            "home.record.error.delete_failed",
            service: localizationService,
            en: "This delete didn't complete. Try again.",
            zh: "这次删除没有成功，请再试一次。"
        )
    }

    private func undoFailedMessage() -> String {
        L10n.text(
            "home.record.error.undo_failed",
            service: localizationService,
            en: "This undo didn't complete. Try again.",
            zh: "这次撤销没有成功，请再试一次。"
        )
    }

    private func updatedRecordMessage() -> String {
        L10n.text(
            "home.record.updated",
            service: localizationService,
            en: "Record updated.",
            zh: "已更新记录"
        )
    }

    private func deleteUndoMessage() -> String {
        L10n.text(
            "home.record.deleted",
            service: localizationService,
            en: "Record deleted.",
            zh: "已删除记录"
        )
    }

    private func restoredRecordMessage() -> String {
        L10n.text(
            "home.record.restored",
            service: localizationService,
            en: "Record restored.",
            zh: "已恢复记录"
        )
    }

    private func recordRecoverySnapshot(from snapshot: DeletedRecordSnapshot) -> RecordRecoverySnapshot {
        RecordRecoverySnapshot(
            recordID: snapshot.recordID,
            timestamp: snapshot.timestamp,
            type: snapshot.type,
            value: snapshot.value,
            leftNursingSeconds: snapshot.leftNursingSeconds,
            rightNursingSeconds: snapshot.rightNursingSeconds,
            subType: snapshot.subType,
            imageURL: snapshot.imageURL,
            aiSummary: snapshot.aiSummary,
            tags: snapshot.tags,
            note: snapshot.note
        )
    }

    private func finalizeDeletedRecordSnapshot(_ snapshot: DeletedRecordSnapshot) {
        guard let recordRepository else { return }

        do {
            try recordRepository.finalizeDeletedRecord(recordRecoverySnapshot(from: snapshot))
        } catch {
            let errorDescription = String(describing: error)
            AppLogger.persistence.error("Finalize deleted record failed: \(errorDescription, privacy: .public)")
        }
    }

    private func handlePersistenceError(_ error: Error, logMessage: String, userMessage: String) {
        let errorDescription = String(describing: error)
        AppLogger.persistence.error("\(logMessage, privacy: .public): \(errorDescription, privacy: .public)")
        showMessageToast(userMessage)
    }

    private func canonicalFoodTag(matching tag: String) -> String {
        let canonicalTag = foodTagCatalog.canonicalTag(for: tag)
        guard !canonicalTag.isEmpty else { return "" }

        for candidate in foodDraft.selectedTags + allSuggestedFoodTags
        where foodTagsMatch(candidate, tag) {
            return candidate
        }

        return canonicalTag
    }

    private func containsFoodTag(_ tag: String, in tags: [String]) -> Bool {
        tags.contains { foodTagsMatch($0, tag) }
    }

    private func foodTagsMatch(_ lhs: String, _ rhs: String) -> Bool {
        foodTagCatalog.isEquivalentTag(lhs, rhs)
    }

    private func matchesFoodTagSearch(_ candidate: String, query: String) -> Bool {
        if foodTagCatalog.isEquivalentTag(candidate, query) {
            return true
        }

        let canonicalQuery = foodTagCatalog.canonicalTag(for: query)
        let queryCandidates = [query, canonicalQuery]
            .map(\.trimmed)
            .filter { !$0.isEmpty }

        return queryCandidates.contains { searchTerm in
            candidate.range(
                of: searchTerm,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil,
                locale: localizationService.locale
            ) != nil
        }
    }

    private func uniqueFoodTags(from tags: [String]) -> [String] {
        var uniqueTags: [String] = []

        for tag in tags {
            let canonicalTag = foodTagCatalog.canonicalTag(for: tag)
            guard !canonicalTag.isEmpty else { continue }
            guard !containsFoodTag(canonicalTag, in: uniqueTags) else { continue }
            uniqueTags.append(canonicalTag)
        }

        return uniqueTags
    }

    private func updateFirstTasteFoodTags() {
        let selectedTags = foodDraft.selectedTags
            .map(\.trimmed)
            .filter { !$0.isEmpty }

        viewState.firstTasteFoodTags = selectedTags.filter { tag in
            !containsFoodTag(tag, in: viewState.knownFoodTags)
        }
    }

    private func makeFirstTasteHintMessage(tags: [String]) -> String {
        if tags.count == 1, let tag = tags.first {
            return L10n.format(
                "home.sheet.food.first_taste.single",
                service: localizationService,
                locale: localizationService.locale,
                en: "First time trying %@",
                zh: "第一次尝试%@",
                arguments: [tag]
            )
        }

        return L10n.format(
            "home.sheet.food.first_taste.multiple",
            service: localizationService,
            locale: localizationService.locale,
            en: "First time trying: %@",
            zh: "第一次尝试：%@",
            arguments: [localeFormatter.list(tags)]
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
