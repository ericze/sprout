import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TreasureStore {
    var viewState = TreasureViewState()

    var headerConfig: HomeHeaderConfig

    @ObservationIgnored private var repository: TreasureRepository?
    @ObservationIgnored private let timelineBuilder: TreasureTimelineBuilder
    @ObservationIgnored private let monthAnchorBuilder: TreasureMonthAnchorBuilder
    @ObservationIgnored private let weeklyLetterComposer: WeeklyLetterComposer
    @ObservationIgnored private let monthHintStore: TreasureMonthHintStore
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let dateProvider: () -> Date
    @ObservationIgnored private let imageRemover: @MainActor ([String]) -> Void
    @ObservationIgnored private var undoDismissTask: Task<Void, Never>?
    @ObservationIgnored private var monthScrubberFadeTask: Task<Void, Never>?
    @ObservationIgnored private var monthHintTask: Task<Void, Never>?
    @ObservationIgnored private var fabRevealTask: Task<Void, Never>?
    @ObservationIgnored private var isScrollInteractionActive = false
    @ObservationIgnored private var lastScrollOffset: CGFloat?
    @ObservationIgnored private var lastScrollTimestamp: TimeInterval?

    init(
        headerConfig: HomeHeaderConfig,
        repository: TreasureRepository? = nil,
        timelineBuilder: TreasureTimelineBuilder? = nil,
        monthAnchorBuilder: TreasureMonthAnchorBuilder? = nil,
        weeklyLetterComposer: WeeklyLetterComposer? = nil,
        monthHintStore: TreasureMonthHintStore? = nil,
        calendar: Calendar = .current,
        dateProvider: @escaping () -> Date = Date.init,
        imageRemover: @escaping @MainActor ([String]) -> Void = TreasurePhotoStorage.removeImages(at:)
    ) {
        var resolvedCalendar = calendar
        resolvedCalendar.firstWeekday = 2
        resolvedCalendar.minimumDaysInFirstWeek = 4

        self.headerConfig = headerConfig
        self.repository = repository
        self.timelineBuilder = timelineBuilder ?? TreasureTimelineBuilder(calendar: resolvedCalendar)
        self.monthAnchorBuilder = monthAnchorBuilder ?? TreasureMonthAnchorBuilder(calendar: resolvedCalendar)
        self.weeklyLetterComposer = weeklyLetterComposer ?? WeeklyLetterComposer(calendar: resolvedCalendar)
        self.monthHintStore = monthHintStore ?? TreasureMonthHintStore()
        self.calendar = resolvedCalendar
        self.dateProvider = dateProvider
        self.imageRemover = imageRemover
    }

    deinit {
        undoDismissTask?.cancel()
        monthScrubberFadeTask?.cancel()
        monthHintTask?.cancel()
        fabRevealTask?.cancel()
    }
}

extension TreasureStore {
    var isComposeSaveEnabled: Bool {
        viewState.composeDraft.canSave && viewState.composeState != .saving
    }

    var shouldShowDiscardConfirmation: Bool {
        viewState.composeState == .confirmingDiscard
    }

    var shouldShowComposeFailure: Bool {
        viewState.composeState == .failed
    }

    var composeFailureMessage: String {
        viewState.composeErrorMessage ?? "没有保存成功，请再试一次。"
    }

    func configure(modelContext: ModelContext) {
        guard repository == nil else { return }
        repository = TreasureRepository(modelContext: modelContext, calendar: calendar)
    }

    func updateHeaderConfig(_ config: HomeHeaderConfig) {
        headerConfig = config
    }

    func onAppear() {
        handle(.onAppear)
    }

    func consumeScrollTarget() {
        viewState.scrollTargetID = nil
    }

    func handle(_ action: TreasureAction) {
        switch action {
        case .onAppear:
            guard !viewState.hasLoadedInitialData else { return }
            resetScrollTracking()
            refreshTimeline()
            viewState.hasLoadedInitialData = true

        case let .didScroll(offset, timestamp):
            updateScroll(offset: offset, timestamp: timestamp)

        case .beginScrollInteraction:
            beginScrollInteraction()

        case .endScrollInteraction:
            endScrollInteraction()

        case .tapAddToday:
            beginCompose()

        case .dismissCompose:
            requestComposeDismiss()

        case .confirmDiscard:
            discardComposeDraft()

        case .cancelDiscard:
            viewState.composeState = editingState(for: viewState.composeDraft)

        case let .updateNote(note):
            viewState.composeDraft.note = note
            refreshComposeState()

        case .toggleMilestone:
            viewState.composeDraft.isMilestone.toggle()
            refreshComposeState()
            AppHaptics.selection()

        case let .appendImagePaths(paths):
            appendImagePaths(paths)

        case let .replaceImagePaths(paths):
            replaceImagePaths(paths)

        case let .removeImage(at: index):
            removeDraftImage(at: index)

        case .saveCompose:
            saveCompose()

        case .retrySaveCompose:
            saveCompose()

        case .dismissComposeError:
            viewState.composeErrorMessage = nil
            viewState.composeState = editingState(for: viewState.composeDraft)

        case .undoLastEntry:
            undoLastEntry()

        case .dismissUndo:
            dismissUndoToast()

        case let .tapWeeklyLetter(id):
            openWeeklyLetter(id: id)

        case .dismissWeeklyLetter:
            closeWeeklyLetter()

        case let .beginMonthScrubbing(height, locationY):
            beginMonthScrubbing(height: height, locationY: locationY)

        case let .updateMonthScrubbing(height, locationY):
            updateMonthScrubbing(height: height, locationY: locationY)

        case .endMonthScrubbing:
            endMonthScrubbing()
        }
    }

    private func updateScroll(offset: CGFloat, timestamp: TimeInterval) {
        guard viewState.hasLoadedInitialData else { return }
        defer {
            lastScrollOffset = offset
            lastScrollTimestamp = timestamp
        }

        guard viewState.monthScrubberState != .dragging else { return }

        let previousOffset = lastScrollOffset ?? offset
        let previousTimestamp = lastScrollTimestamp ?? timestamp
        let previousDistanceFromTop = abs(previousOffset)
        let currentDistanceFromTop = abs(offset)
        let delta = currentDistanceFromTop - previousDistanceFromTop
        let duration = max(timestamp - previousTimestamp, 0.001)
        let velocity = abs(delta) / duration

        if currentDistanceFromTop <= 24 {
            setFloatingAddButtonVisible(true)
            if viewState.scrollIntentState != .monthScrubbing {
                viewState.scrollIntentState = .idle
            }
        } else if delta < -0.5 {
            viewState.scrollIntentState = .reversingUp
            setFloatingAddButtonVisible(true)
        } else if delta > 0.5 {
            viewState.scrollIntentState = velocity > 1500 ? .fastScrolling : .readingDown
            setFloatingAddButtonVisible(false)
        }

        if isScrollInteractionActive {
            cancelFloatingAddButtonReveal()
        } else {
            scheduleFloatingAddButtonReveal()
        }

        guard viewState.monthAnchors.count >= 2 else {
            if viewState.monthScrubberState != .onboardingNudge {
                viewState.monthScrubberState = .hidden
            }
            return
        }

        if velocity > 1500, currentDistanceFromTop > 60 {
            showMonthScrubber()
        }
    }

    private func beginCompose() {
        viewState.composeDraft.reset()
        viewState.composeErrorMessage = nil
        viewState.composeState = .editingEmpty
        AppHaptics.lightImpact()
    }

    private func requestComposeDismiss() {
        if viewState.composeDraft.hasAnyUserIntent {
            viewState.composeState = .confirmingDiscard
        } else {
            closeCompose(removeDraftAssets: false)
        }
    }

    private func discardComposeDraft() {
        closeCompose(removeDraftAssets: true)
    }

    private func appendImagePaths(_ paths: [String]) {
        let normalizedPaths = normalizeImagePaths(paths)
        guard !normalizedPaths.isEmpty else { return }

        let existingPaths = viewState.composeDraft.imageLocalPaths
        let combinedPaths = existingPaths + normalizedPaths
        let keptPaths = Array(combinedPaths.prefix(TreasureLimits.maxImagesPerEntry))
        let overflowPaths = Array(combinedPaths.dropFirst(TreasureLimits.maxImagesPerEntry))

        if !overflowPaths.isEmpty {
            imageRemover(overflowPaths)
        }

        viewState.composeDraft.imageLocalPaths = keptPaths
        refreshComposeState()

        if keptPaths != existingPaths {
            AppHaptics.lightImpact()
        }
    }

    private func replaceImagePaths(_ paths: [String]) {
        let normalizedPaths = normalizeImagePaths(paths)
        let keptPaths = Array(normalizedPaths.prefix(TreasureLimits.maxImagesPerEntry))
        let overflowPaths = Array(normalizedPaths.dropFirst(TreasureLimits.maxImagesPerEntry))
        let removedPaths = viewState.composeDraft.imageLocalPaths.filter { !keptPaths.contains($0) }

        if !removedPaths.isEmpty || !overflowPaths.isEmpty {
            imageRemover(removedPaths + overflowPaths)
        }

        viewState.composeDraft.imageLocalPaths = keptPaths
        refreshComposeState()
    }

    private func removeDraftImage(at index: Int) {
        guard viewState.composeDraft.imageLocalPaths.indices.contains(index) else { return }

        let removedPath = viewState.composeDraft.imageLocalPaths.remove(at: index)
        imageRemover([removedPath])
        refreshComposeState()
    }

    private func saveCompose() {
        guard let repository, isComposeSaveEnabled else { return }

        viewState.composeErrorMessage = nil
        viewState.composeState = .saving

        do {
            let now = dateProvider()
            let createdEntry = try repository.createMemoryEntry(
                note: viewState.composeDraft.note,
                imageLocalPaths: viewState.composeDraft.imageLocalPaths,
                isMilestone: viewState.composeDraft.isMilestone,
                createdAt: now,
                birthDate: headerConfig.birthDate
            )

            syncWeeklyLetterIfPossible(for: createdEntry.createdAt)

            viewState.composeDraft.reset()
            viewState.composeState = .closed
            refreshTimeline()
            showUndoToast(recordID: createdEntry.id, message: "已留住今天")
            AppHaptics.success()
        } catch {
            viewState.composeState = .failed
            viewState.composeErrorMessage = "没有保存成功，请再试一次。"
            assertionFailure("Treasure save failed: \(error)")
        }
    }

    private func undoLastEntry() {
        guard let repository, let undoToast = viewState.undoToast else { return }

        do {
            let memoryEntryDate = try repository.fetchMemoryEntry(id: undoToast.recordID)?.createdAt
            try repository.deleteMemoryEntry(id: undoToast.recordID)
            if let memoryEntryDate {
                syncWeeklyLetterIfPossible(for: memoryEntryDate)
            }
            dismissUndoToast()
            refreshTimeline()
        } catch {
            assertionFailure("Treasure undo failed: \(error)")
        }
    }

    private func openWeeklyLetter(id: UUID) {
        guard let item = viewState.timelineItems.first(where: { $0.id == id }), item.canOpenWeeklyLetter else { return }
        viewState.selectedWeeklyLetter = item
        viewState.weeklyLetterViewState = .expandedBottomSheet
        AppHaptics.lightImpact()
    }

    private func closeWeeklyLetter() {
        viewState.selectedWeeklyLetter = nil
        viewState.weeklyLetterViewState = .collapsed
    }

    private func beginMonthScrubbing(height: CGFloat, locationY: CGFloat) {
        guard viewState.monthAnchors.count >= 2 else { return }
        cancelMonthScrubberFade()
        cancelFloatingAddButtonReveal()
        viewState.monthScrubberState = .dragging
        viewState.scrollIntentState = .monthScrubbing
        updateMonthScrubbing(height: height, locationY: locationY)
        AppHaptics.selection()
    }

    private func updateMonthScrubbing(height: CGFloat, locationY: CGFloat) {
        guard let anchor = monthAnchor(for: height, locationY: locationY) else { return }
        if viewState.activeMonthAnchor != anchor {
            viewState.activeMonthAnchor = anchor
            AppHaptics.selection()
        }
        requestScroll(to: anchor.firstTimelineItemID)
    }

    private func endMonthScrubbing() {
        guard viewState.monthScrubberState == .dragging else { return }
        viewState.monthScrubberState = .visible
        viewState.scrollIntentState = .idle
        scheduleMonthScrubberFade(after: 1.2)
    }

    private func refreshTimeline() {
        guard let repository else {
            viewState.dataState = .error
            viewState.errorMessage = "珍藏内容暂不可用"
            return
        }

        do {
            let entries = try repository.fetchMemoryEntries()
            let weeklyLetters = try repository.fetchWeeklyLetters()
            let allItems = timelineBuilder.makeTimelineItems(entries: entries, weeklyLetters: weeklyLetters)
            let anchors = monthAnchorBuilder.build(from: allItems)

            viewState.timelineItems = allItems
            viewState.monthAnchors = anchors
            viewState.activeMonthAnchor = activeAnchor(for: anchors)
            syncSelectedWeeklyLetter(with: allItems)
            viewState.errorMessage = nil
            viewState.dataState = dataState(totalItems: allItems.count)

            if anchors.count < 2, viewState.monthScrubberState != .dragging {
                cancelMonthScrubberFade()
                cancelMonthHintTask()
                viewState.monthScrubberState = .hidden
            }

            showMonthHintIfNeeded(with: anchors)
        } catch {
            viewState.dataState = .error
            viewState.errorMessage = "珍藏内容加载失败"
            assertionFailure("Treasure refresh failed: \(error)")
        }
    }

    private func showMonthHintIfNeeded(with anchors: [TreasureMonthAnchor]) {
        guard
            anchors.count >= 2,
            !monthHintStore.hasShownHint(),
            !viewState.hasLoadedInitialData
        else {
            return
        }

        monthHintStore.markShown()
        cancelMonthScrubberFade()
        cancelMonthHintTask()
        viewState.monthScrubberState = .onboardingNudge

        monthHintTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled, self.viewState.monthScrubberState == .onboardingNudge else { return }
            self.viewState.monthScrubberState = .hidden
            self.monthHintTask = nil
        }
    }

    private func dataState(totalItems: Int) -> TreasureDataState {
        if totalItems == 0 {
            return .empty
        }
        if totalItems <= 2 {
            return .lowContent
        }
        return .ready
    }

    private func refreshComposeState() {
        guard viewState.composeState != .saving, viewState.composeState != .failed else { return }
        viewState.composeState = editingState(for: viewState.composeDraft)
    }

    private func editingState(for draft: TreasureComposeDraft) -> TreasureComposeState {
        if draft.hasImage && draft.hasText {
            return .editingPhotoAndText
        }
        if draft.hasImage {
            return .editingPhotoOnly
        }
        if draft.hasText {
            return .editingTextOnly
        }
        if draft.isMilestone {
            return .editingMilestone
        }
        return .editingEmpty
    }

    private func closeCompose(removeDraftAssets: Bool) {
        if removeDraftAssets {
            imageRemover(viewState.composeDraft.imageLocalPaths)
        }
        viewState.composeDraft.reset()
        viewState.composeErrorMessage = nil
        viewState.composeState = .closed
    }

    private func showUndoToast(recordID: UUID, message: String) {
        undoDismissTask?.cancel()
        viewState.undoToast = UndoToastState(recordID: recordID, message: message)

        undoDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            self.viewState.undoToast = nil
            self.undoDismissTask = nil
        }
    }

    private func dismissUndoToast() {
        undoDismissTask?.cancel()
        undoDismissTask = nil
        viewState.undoToast = nil
    }

    private func showMonthScrubber() {
        guard viewState.monthAnchors.count >= 2 else { return }
        cancelMonthScrubberFade()
        if viewState.monthScrubberState != .dragging {
            viewState.monthScrubberState = .visible
        }
        if viewState.activeMonthAnchor == nil {
            viewState.activeMonthAnchor = viewState.monthAnchors.first
        }
        scheduleMonthScrubberFade(after: 1.2)
    }

    private func resetMonthScrubber() {
        cancelMonthScrubberFade()
        cancelMonthHintTask()
        viewState.monthScrubberState = .hidden
        viewState.activeMonthAnchor = viewState.monthAnchors.first
    }

    private func scheduleMonthScrubberFade(after delay: TimeInterval) {
        monthScrubberFadeTask?.cancel()
        monthScrubberFadeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, self.viewState.monthScrubberState == .visible else { return }
            self.viewState.monthScrubberState = .fading
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            self.viewState.monthScrubberState = .hidden
            self.monthScrubberFadeTask = nil
        }
    }

    private func cancelMonthScrubberFade() {
        monthScrubberFadeTask?.cancel()
        monthScrubberFadeTask = nil
    }

    private func cancelMonthHintTask() {
        monthHintTask?.cancel()
        monthHintTask = nil
    }

    private func requestScroll(to id: UUID) {
        viewState.scrollTargetID = nil
        viewState.scrollTargetID = id
    }

    private func activeAnchor(for anchors: [TreasureMonthAnchor]) -> TreasureMonthAnchor? {
        if let currentAnchor = viewState.activeMonthAnchor,
           let matched = anchors.first(where: { $0.id == currentAnchor.id }) {
            return matched
        }
        return anchors.first
    }

    private func syncSelectedWeeklyLetter(with items: [TreasureTimelineItem]) {
        guard let selectedWeeklyLetter = viewState.selectedWeeklyLetter else { return }

        if let refreshedItem = items.first(where: { $0.id == selectedWeeklyLetter.id && $0.canOpenWeeklyLetter }) {
            viewState.selectedWeeklyLetter = refreshedItem
        } else {
            closeWeeklyLetter()
        }
    }

    private func monthAnchor(for height: CGFloat, locationY: CGFloat) -> TreasureMonthAnchor? {
        guard !viewState.monthAnchors.isEmpty else { return nil }
        let clampedProgress = min(max(locationY / max(height, 1), 0), 0.999)
        let index = min(Int(clampedProgress * CGFloat(viewState.monthAnchors.count)), viewState.monthAnchors.count - 1)
        return viewState.monthAnchors[index]
    }

    private func weekStart(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: components) ?? date
        return calendar.startOfDay(for: start)
    }

    private func syncWeeklyLetterIfPossible(for date: Date) {
        guard let repository else { return }

        do {
            try repository.syncWeeklyLetter(
                for: weekStart(for: date),
                composer: weeklyLetterComposer,
                generatedAt: dateProvider()
            )
        } catch {
            assertionFailure("Treasure weekly letter sync failed: \(error)")
        }
    }

    private func resetScrollTracking() {
        isScrollInteractionActive = false
        lastScrollOffset = nil
        lastScrollTimestamp = nil
        cancelFloatingAddButtonReveal()
        setFloatingAddButtonVisible(true)
        if viewState.scrollIntentState != .monthScrubbing {
            viewState.scrollIntentState = .idle
        }
    }

    private func beginScrollInteraction() {
        guard !isScrollInteractionActive else { return }
        isScrollInteractionActive = true
        cancelFloatingAddButtonReveal()
    }

    private func endScrollInteraction() {
        guard isScrollInteractionActive else { return }
        isScrollInteractionActive = false

        guard viewState.monthScrubberState != .dragging else { return }

        if let lastScrollOffset, abs(lastScrollOffset) <= 24 {
            setFloatingAddButtonVisible(true)
        } else {
            scheduleFloatingAddButtonReveal()
        }
    }

    private func normalizeImagePaths(_ paths: [String]) -> [String] {
        paths.compactMap { $0.trimmed.nilIfEmpty }
    }

    private func setFloatingAddButtonVisible(_ isVisible: Bool) {
        viewState.isFloatingAddButtonVisible = isVisible
    }

    private func scheduleFloatingAddButtonReveal() {
        cancelFloatingAddButtonReveal()
        fabRevealTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard let self, !Task.isCancelled, self.viewState.monthScrubberState != .dragging else { return }
            self.setFloatingAddButtonVisible(true)
            self.fabRevealTask = nil
        }
    }

    private func cancelFloatingAddButtonReveal() {
        fabRevealTask?.cancel()
        fabRevealTask = nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
