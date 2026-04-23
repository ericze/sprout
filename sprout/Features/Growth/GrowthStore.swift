import Foundation
import Observation
import OSLog
import SwiftData

@MainActor
@Observable
final class GrowthStore {
    var viewState = GrowthViewState()

    var headerConfig: HomeHeaderConfig
    @ObservationIgnored let textRenderer: GrowthTextRenderer
    @ObservationIgnored var onMilestoneChanged: ((Date) -> Void)?

    @ObservationIgnored private var repository: GrowthRecordRepository?
    @ObservationIgnored private var milestoneRepository: GrowthMilestoneRepository?
    @ObservationIgnored private var lastDeletedMilestone: GrowthMilestoneEntry?
    @ObservationIgnored private let formatter: GrowthFormatter
    @ObservationIgnored private let localizationService: LocalizationService
    @ObservationIgnored private let referenceRangeStore: GrowthReferenceRangeStore
    @ObservationIgnored private let metricPreferenceStore: GrowthMetricPreferenceStore
    @ObservationIgnored private let chartInteractionController: GrowthChartInteractionController
    @ObservationIgnored private let productConfig: GrowthProductConfig
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let dateProvider: () -> Date
    @ObservationIgnored private var precisionFadeTask: Task<Void, Never>?
    @ObservationIgnored private var undoDismissTask: Task<Void, Never>?
    @ObservationIgnored private var messageDismissTask: Task<Void, Never>?

    init(
        headerConfig: HomeHeaderConfig,
        repository: GrowthRecordRepository? = nil,
        formatter: GrowthFormatter? = nil,
        localizationService: LocalizationService? = nil,
        textRenderer: GrowthTextRenderer? = nil,
        referenceRangeStore: GrowthReferenceRangeStore = GrowthReferenceRangeStore(),
        metricPreferenceStore: GrowthMetricPreferenceStore = GrowthMetricPreferenceStore(),
        chartInteractionController: GrowthChartInteractionController = GrowthChartInteractionController(),
        productConfig: GrowthProductConfig = .appDefault,
        calendar: Calendar = .current,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        let resolvedLocalizationService = localizationService ?? .current
        self.headerConfig = headerConfig
        self.repository = repository
        self.localizationService = resolvedLocalizationService
        self.formatter = formatter ?? GrowthFormatter(calendar: calendar)
        self.textRenderer = textRenderer ?? GrowthTextRenderer(localizationService: resolvedLocalizationService)
        self.referenceRangeStore = referenceRangeStore
        self.metricPreferenceStore = metricPreferenceStore
        self.chartInteractionController = chartInteractionController
        self.productConfig = productConfig
        self.calendar = calendar
        self.dateProvider = dateProvider
    }

    deinit {
        precisionFadeTask?.cancel()
        undoDismissTask?.cancel()
        messageDismissTask?.cancel()
    }
}
extension GrowthStore {
    var isSaveEnabled: Bool {
        currentValidatedDraftValue() != nil
    }

    var currentRulerConfig: GrowthRulerConfig {
        GrowthRulerConfig.for(currentSheetMetric ?? viewState.currentMetric, productConfig: productConfig)
    }

    func configure(modelContext: ModelContext) {
        if repository == nil {
            repository = GrowthRecordRepository(modelContext: modelContext)
        }
        if milestoneRepository == nil {
            milestoneRepository = GrowthMilestoneRepository(modelContext: modelContext)
        }
    }

    func updateHeaderConfig(_ config: HomeHeaderConfig) {
        headerConfig = config
    }

    func refreshAfterProfileChange() {
        guard viewState.hasLoadedInitialData else { return }
        refreshCurrentMetric()
    }

    func onAppear() {
        handle(.onAppear)
    }

    func handle(_ action: GrowthAction) {
        switch action {
        case .onAppear:
            guard !viewState.hasLoadedInitialData else { return }
            viewState.currentMetric = metricPreferenceStore.load() ?? .height
            refreshCurrentMetric()
            refreshMilestones()
            viewState.hasLoadedInitialData = true

        case let .selectMetric(metric):
            selectMetric(metric)

        case .toggleAIState:
            viewState.aiState = viewState.aiState == .expanded ? .collapsed : .expanded
            AppHaptics.selection()

        case .tapEntry:
            prepareEntryDraft(for: viewState.currentMetric)
            viewState.sheetState = viewState.currentMetric == .height ? .openHeight : .openWeight
            AppHaptics.lightImpact()

        case .dismissSheet:
            viewState.sheetState = .closed

        case .switchToManualInput:
            guard let metric = currentSheetMetric else { return }
            syncDraftManualText()
            viewState.sheetState = metric == .height ? .manualInputHeight : .manualInputWeight
            AppHaptics.selection()

        case .switchToRulerInput:
            guard let metric = currentSheetMetric else { return }
            viewState.sheetState = metric == .height ? .openHeight : .openWeight
            AppHaptics.selection()

        case let .updateManualInput(text):
            updateManualInput(text)

        case let .updateRulerValue(value):
            guard let metric = currentSheetMetric else { return }
            viewState.entryDraft.value = normalizedValue(value, for: metric)
            syncDraftManualText()

        case .saveRecord:
            saveRecord()

        case .undoLastRecord:
            undoLastRecord()

        case .dismissUndo:
            dismissUndoToast()

        case .dismissMessage:
            dismissMessageToast()

        case let .beginScrubbing(locationX, plotWidth):
            beginScrubbing(at: locationX, plotWidth: plotWidth)

        case let .updateScrubbing(locationX, plotWidth):
            updateScrubbing(at: locationX, plotWidth: plotWidth)

        case .endScrubbing:
            endScrubbing()

        case .tapAddMilestone:
            viewState.milestoneDraft = GrowthMilestoneDraft()
            viewState.milestoneSheetState = .add

        case let .tapEditMilestone(entry):
            viewState.milestoneDraft = GrowthMilestoneDraft(
                id: entry.id,
                templateKey: entry.templateKey,
                customTitle: entry.title,
                category: GrowthMilestoneCategory(rawValue: entry.category) ?? .motor,
                occurredAt: entry.occurredAt,
                note: entry.note ?? "",
                imageLocalPath: entry.imageLocalPath,
                isCustom: entry.isCustom
            )
            viewState.milestoneSheetState = .edit(entry)

        case .dismissMilestoneSheet:
            viewState.milestoneSheetState = .closed

        case let .updateMilestoneDraft(draft):
            viewState.milestoneDraft = draft

        case .saveMilestone:
            saveMilestone()

        case let .deleteMilestone(id):
            deleteMilestone(id: id)

        case .undoDeletedMilestone:
            undoDeletedMilestone()

        case .dismissMilestoneUndo:
            dismissMilestoneUndo()
        }
    }

    private var currentSheetMetric: GrowthMetric? {
        viewState.sheetState.metric
    }

    private func selectMetric(_ metric: GrowthMetric) {
        guard viewState.currentMetric != metric else { return }
        resetPrecisionState()
        viewState.currentMetric = metric
        metricPreferenceStore.save(metric)
        refreshCurrentMetric()
        AppHaptics.selection()
    }

    private func refreshCurrentMetric() {
        viewState.currentAgeInDays = currentAgeInDays(at: dateProvider())
        viewState.errorMessage = nil

        guard let repository else {
            viewState.dataState = .error
            viewState.errorMessage = textRenderer.unavailableMessage()
            return
        }

        do {
            let records = try repository.fetchRecords(for: viewState.currentMetric)
            let points = formatter.makePoints(from: records, metric: viewState.currentMetric, birthDate: headerConfig.birthDate)
            let maxAgeInDays = max(
                viewState.currentAgeInDays + productConfig.chartTrailingAgePaddingInDays,
                points.last?.ageInDays ?? 0,
                productConfig.chartMinimumVisibleAgeInDays
            )

            viewState.points = points
            viewState.referenceBands = referenceRangeStore.referenceBands(
                for: viewState.currentMetric,
                maxAgeInDays: maxAgeInDays
            )
            viewState.metaInfo = formatter.makeMetaInfo(from: points, metric: viewState.currentMetric, now: dateProvider())
            viewState.aiContent = formatter.makeAIContent(from: points, metric: viewState.currentMetric)
            viewState.yAxisLabels = formatter.makeYAxisLabels(
                points: points,
                referenceBands: viewState.referenceBands,
                metric: viewState.currentMetric
            )
            viewState.dataState = points.isEmpty ? .empty : .hasData
        } catch {
            viewState.dataState = .error
            viewState.errorMessage = textRenderer.loadFailedMessage()
            logPersistenceError(error, message: "Growth refresh failed")
        }
    }

    private func prepareEntryDraft(for metric: GrowthMetric) {
        let initialValue = latestValue(for: metric) ?? productConfig.defaultValue(for: metric)
        viewState.entryDraft.value = normalizedValue(initialValue, for: metric)
        viewState.entryDraft.manualInput = textRenderer.editableValue(viewState.entryDraft.value)
    }

    private func latestValue(for metric: GrowthMetric) -> Double? {
        if viewState.currentMetric == metric {
            return viewState.points.last?.value
        }

        guard let repository else { return nil }
        do {
            return try repository.fetchLatestRecord(for: metric)?.value
        } catch {
            logPersistenceError(error, message: "Fetch latest growth record failed")
            return nil
        }
    }

    private func updateManualInput(_ text: String) {
        guard let metric = currentSheetMetric else { return }
        let sanitized = sanitizeManualInput(text)
        viewState.entryDraft.manualInput = sanitized

        guard let value = parsedManualInputValue(from: sanitized) else { return }
        viewState.entryDraft.value = normalizedValue(value, for: metric)
    }

    private func saveRecord() {
        guard
            let metric = currentSheetMetric,
            let repository,
            let value = currentValidatedDraftValue()
        else {
            return
        }

        do {
            let record = try repository.createRecord(metric: metric, value: value, at: dateProvider())
            viewState.sheetState = .closed
            refreshCurrentMetric()
            showUndoToast(recordID: record.id, message: textRenderer.undoMessage(value: value, metric: metric))
            AppHaptics.success()
        } catch {
            logPersistenceError(error, message: "Growth save failed")
            showMessageToast(
                L10n.text(
                    "growth.error.save",
                    service: localizationService,
                    en: "Couldn't save this growth record. Try again.",
                    zh: "这次成长记录没有保存成功，请再试一次。"
                )
            )
        }
    }

    private func undoLastRecord() {
        guard let repository, let undoToast = viewState.undoToast else { return }

        do {
            try repository.deleteRecord(id: undoToast.recordID)
            dismissUndoToast()
            refreshCurrentMetric()
        } catch {
            logPersistenceError(error, message: "Growth undo failed")
            showMessageToast(
                L10n.text(
                    "growth.error.undo",
                    service: localizationService,
                    en: "Couldn't undo that growth record. Try again.",
                    zh: "这次撤销成长记录没有成功，请再试一次。"
                )
            )
        }
    }

    private func beginScrubbing(at locationX: CGFloat, plotWidth: CGFloat) {
        guard !viewState.points.isEmpty else { return }
        cancelPrecisionFade()
        if viewState.chartInteractionState == .idle {
            viewState.chartInteractionState = .scrubbing
        }
        updateScrubbing(at: locationX, plotWidth: plotWidth)
    }

    private func updateScrubbing(at locationX: CGFloat, plotWidth: CGFloat) {
        guard
            !viewState.points.isEmpty,
            let index = chartInteractionController.nearestIndex(
                locationX: locationX,
                chartWidth: plotWidth,
                itemCount: viewState.points.count
            )
        else {
            return
        }

        let point = viewState.points[index]
        viewState.selection = GrowthChartSelection(
            index: index,
            point: point,
            tooltip: formatter.makeTooltip(for: point, metric: viewState.currentMetric)
        )
        viewState.chartInteractionState = .precisionVisible
    }

    private func endScrubbing() {
        guard viewState.selection != nil else {
            viewState.chartInteractionState = .idle
            return
        }

        cancelPrecisionFade()
        precisionFadeTask = chartInteractionController.scheduleFade(
            onTransition: { [weak self] in
                self?.viewState.chartInteractionState = .precisionFading
            },
            onCompletion: { [weak self] in
                self?.viewState.chartInteractionState = .idle
                self?.viewState.selection = nil
                self?.precisionFadeTask = nil
            }
        )
    }

    private func resetPrecisionState() {
        cancelPrecisionFade()
        viewState.chartInteractionState = .idle
        viewState.selection = nil
    }

    private func cancelPrecisionFade() {
        precisionFadeTask?.cancel()
        precisionFadeTask = nil
    }

    private func currentValidatedDraftValue() -> Double? {
        guard let metric = currentSheetMetric else { return nil }

        if viewState.sheetState.isManualInput {
            guard let value = parsedManualInputValue(from: viewState.entryDraft.manualInput) else { return nil }
            return clampedValue(value, for: metric)
        }

        return clampedValue(viewState.entryDraft.value, for: metric)
    }

    private func syncDraftManualText() {
        viewState.entryDraft.manualInput = textRenderer.editableValue(viewState.entryDraft.value)
    }

    private func normalizedValue(_ value: Double, for metric: GrowthMetric) -> Double {
        let precision = GrowthRulerConfig.for(metric, productConfig: productConfig).precision
        let rounded = (value / precision).rounded() * precision
        return clampedValue(rounded, for: metric)
    }

    private func clampedValue(_ value: Double, for metric: GrowthMetric) -> Double {
        let range = GrowthRulerConfig.for(metric, productConfig: productConfig).range
        return min(max(value, range.lowerBound), range.upperBound)
    }

    private func sanitizeManualInput(_ text: String) -> String {
        let decimalSeparator = localeDecimalSeparator
        var result = ""
        var hasSeparator = false

        for character in text {
            if character.isNumber {
                result.append(character)
            } else if [".", ",", Character(decimalSeparator)].contains(character), !hasSeparator {
                hasSeparator = true
                result.append(decimalSeparator)
            }
        }

        return result
    }

    private func parsedManualInputValue(from text: String) -> Double? {
        Double(text.replacingOccurrences(of: localeDecimalSeparator, with: "."))
    }

    private var localeDecimalSeparator: String {
        let formatter = NumberFormatter()
        formatter.locale = localizationService.locale
        return formatter.decimalSeparator ?? "."
    }

    private func currentAgeInDays(at date: Date) -> Int {
        max(
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: headerConfig.birthDate),
                to: calendar.startOfDay(for: date)
            ).day ?? 0,
            0
        )
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

    private func showMessageToast(_ message: String) {
        guard viewState.messageToast?.message != message else { return }

        messageDismissTask?.cancel()
        viewState.messageToast = MessageToastState(message: message)

        messageDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            self.viewState.messageToast = nil
            self.messageDismissTask = nil
        }
    }

    private func dismissMessageToast() {
        messageDismissTask?.cancel()
        messageDismissTask = nil
        viewState.messageToast = nil
    }

    private func refreshMilestones() {
        guard let milestoneRepository else { return }
        do {
            viewState.milestones = try milestoneRepository.fetchMilestones(for: headerConfig.babyID)
        } catch {
            logPersistenceError(error, message: "Milestone refresh failed")
        }
    }

    private func saveMilestone() {
        guard let milestoneRepository else { return }
        let draft = viewState.milestoneDraft

        do {
            switch viewState.milestoneSheetState {
            case .add:
                let entry = try milestoneRepository.createMilestone(
                    babyID: headerConfig.babyID,
                    title: draft.isCustom ? draft.customTitle : (draft.templateKey ?? draft.customTitle),
                    templateKey: draft.templateKey,
                    category: draft.category.rawValue,
                    occurredAt: draft.occurredAt,
                    note: draft.note.isEmpty ? nil : draft.note,
                    imageLocalPath: draft.imageLocalPath,
                    isCustom: draft.isCustom
                )
                viewState.milestoneSheetState = .closed
                refreshMilestones()
                showUndoToast(recordID: entry.id, message: textRenderer.milestoneUndoMessage())
                notifyMilestoneChanged(at: draft.occurredAt)

            case let .edit(existingEntry):
                try milestoneRepository.updateMilestone(
                    existingEntry,
                    title: draft.isCustom ? draft.customTitle : (draft.templateKey ?? draft.customTitle),
                    note: draft.note.isEmpty ? nil : draft.note,
                    occurredAt: draft.occurredAt
                )
                viewState.milestoneSheetState = .closed
                refreshMilestones()
                notifyMilestoneChanged(at: existingEntry.occurredAt)
                if draft.occurredAt != existingEntry.occurredAt {
                    notifyMilestoneChanged(at: draft.occurredAt)
                }

            case .closed:
                break
            }
        } catch {
            logPersistenceError(error, message: "Milestone save failed")
            showMessageToast(
                L10n.text(
                    "growth.milestone.error.save",
                    service: localizationService,
                    en: "Couldn't save this milestone. Try again.",
                    zh: "里程碑保存失败，请重试。"
                )
            )
        }
    }

    private func deleteMilestone(id: UUID) {
        guard let milestoneRepository else { return }

        do {
            let occurredAt: Date?
            if let entry = try milestoneRepository.fetchMilestone(id: id) {
                lastDeletedMilestone = entry
                occurredAt = entry.occurredAt
            } else {
                occurredAt = nil
            }
            try milestoneRepository.deleteMilestone(id: id)
            refreshMilestones()
            showUndoToast(recordID: id, message: textRenderer.milestoneUndoMessage())
            if let date = occurredAt {
                notifyMilestoneChanged(at: date)
            }
        } catch {
            logPersistenceError(error, message: "Milestone delete failed")
            showMessageToast(
                L10n.text(
                    "growth.milestone.error.delete",
                    service: localizationService,
                    en: "Couldn't delete this milestone. Try again.",
                    zh: "里程碑删除失败，请重试。"
                )
            )
        }
    }

    private func undoDeletedMilestone() {
        guard let milestoneRepository, let entry = lastDeletedMilestone else { return }

        do {
            let restored = try milestoneRepository.createMilestone(
                babyID: entry.babyID,
                title: entry.title,
                templateKey: entry.templateKey,
                category: entry.category,
                occurredAt: entry.occurredAt,
                note: entry.note,
                imageLocalPath: entry.imageLocalPath,
                isCustom: entry.isCustom
            )
            lastDeletedMilestone = nil
            dismissUndoToast()
            // Update the milestones list to reflect the restored entry
            refreshMilestones()
            notifyMilestoneChanged(at: entry.occurredAt)
            _ = restored
        } catch {
            logPersistenceError(error, message: "Milestone undo failed")
        }
    }

    private func dismissMilestoneUndo() {
        lastDeletedMilestone = nil
        dismissUndoToast()
    }

    private func notifyMilestoneChanged(at date: Date) {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let weekStart = calendar.date(from: components) else { return }
        onMilestoneChanged?(calendar.startOfDay(for: weekStart))
    }

    private func logPersistenceError(_ error: Error, message: String) {
        let errorDescription = String(describing: error)
        AppLogger.persistence.error("\(message, privacy: .public): \(errorDescription, privacy: .public)")
    }
}
