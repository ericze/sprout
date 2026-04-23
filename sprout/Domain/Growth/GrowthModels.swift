import CoreGraphics
import Foundation

enum GrowthMetric: String, Codable, CaseIterable, Identifiable {
    case height
    case weight

    var id: String { rawValue }

    var titleLocalizationKey: String {
        switch self {
        case .height:
            "growth.metric.height.title"
        case .weight:
            "growth.metric.weight.title"
        }
    }

    var entryTitleLocalizationKey: String {
        switch self {
        case .height:
            "growth.metric.height.entry_title"
        case .weight:
            "growth.metric.weight.entry_title"
        }
    }

    var recordType: RecordType {
        switch self {
        case .height:
            .height
        case .weight:
            .weight
        }
    }

    var emptyLocalizationKey: String {
        switch self {
        case .height:
            "growth.metric.height.empty"
        case .weight:
            "growth.metric.weight.empty"
        }
    }

    var unitLocalizationKey: String {
        switch self {
        case .height:
            "unit.centimeter.short"
        case .weight:
            "unit.kilogram.short"
        }
    }
}

enum GrowthChartInteractionState: Equatable {
    case idle
    case scrubbing
    case precisionVisible
    case precisionFading
}

enum GrowthAIState: Equatable {
    case expanded
    case collapsed
}

enum GrowthSheetState: Equatable {
    case closed
    case openHeight
    case openWeight
    case manualInputHeight
    case manualInputWeight

    var isPresented: Bool {
        self != .closed
    }

    var metric: GrowthMetric? {
        switch self {
        case .openHeight, .manualInputHeight:
            .height
        case .openWeight, .manualInputWeight:
            .weight
        case .closed:
            nil
        }
    }

    var isManualInput: Bool {
        self == .manualInputHeight || self == .manualInputWeight
    }
}

enum GrowthDataState: Equatable {
    case loading
    case empty
    case hasData
    case error
}

struct GrowthPoint: Identifiable, Equatable {
    let id: UUID
    let recordID: UUID
    let date: Date
    let ageInDays: Int
    let value: Double
}

struct GrowthMetaInfo: Equatable {
    let metric: GrowthMetric
    let latestValue: Double?
    let latestRecordedAt: Date?
    let referenceDate: Date
}

struct GrowthTooltipData: Equatable {
    let ageInDays: Int
    let value: Double
    let metric: GrowthMetric
}

struct GrowthAIContent: Equatable {
    let expanded: GrowthAIMessage
    let collapsed: GrowthAIMessage
}

enum GrowthAIChangeDirection: Equatable {
    case increased
    case decreased
    case unchanged
}

struct GrowthAIMessage: Equatable {
    enum Kind: Equatable {
        case waitingFirstRecord
        case inviteFirstRecord
        case firstRecordLogged
        case change(intervalDays: Int, direction: GrowthAIChangeDirection, deltaValue: Double)
    }

    let metric: GrowthMetric
    let kind: Kind
}

struct GrowthReferenceBandPoint: Identifiable, Equatable {
    let ageInDays: Int
    let lower: Double
    let upper: Double

    var id: Int { ageInDays }
}

struct GrowthChartSelection: Equatable {
    let index: Int
    let point: GrowthPoint
    let tooltip: GrowthTooltipData
}

struct GrowthYAxisLabel: Identifiable, Equatable {
    let id: String
    let value: Double
    let normalizedY: Double
}

struct GrowthRulerConfig: Equatable {
    let metric: GrowthMetric
    let range: ClosedRange<Double>
    let precision: Double
    let selectionStep: Double
    let strongStep: Double

    static func `for`(_ metric: GrowthMetric, productConfig: GrowthProductConfig) -> GrowthRulerConfig {
        switch metric {
        case .height:
            return GrowthRulerConfig(
                metric: .height,
                range: productConfig.heightRange,
                precision: 0.1,
                selectionStep: 0.5,
                strongStep: 1.0
            )
        case .weight:
            return GrowthRulerConfig(
                metric: .weight,
                range: productConfig.weightRange,
                precision: 0.1,
                selectionStep: 0.1,
                strongStep: 0.5
            )
        }
    }
}

struct GrowthEntryDraftState: Equatable {
    var value: Double = 0
    var manualInput: String = ""
}

struct GrowthViewState: Equatable {
    var currentMetric: GrowthMetric = .height
    var chartInteractionState: GrowthChartInteractionState = .idle
    var aiState: GrowthAIState = .expanded
    var sheetState: GrowthSheetState = .closed
    var dataState: GrowthDataState = .loading
    var points: [GrowthPoint] = []
    var referenceBands: [GrowthReferenceBandPoint] = []
    var metaInfo = GrowthMetaInfo(metric: .height, latestValue: nil, latestRecordedAt: nil, referenceDate: .now)
    var aiContent = GrowthAIContent(
        expanded: GrowthAIMessage(metric: .height, kind: .inviteFirstRecord),
        collapsed: GrowthAIMessage(metric: .height, kind: .waitingFirstRecord)
    )
    var selection: GrowthChartSelection?
    var yAxisLabels: [GrowthYAxisLabel] = []
    var entryDraft = GrowthEntryDraftState()
    var undoToast: UndoToastState?
    var messageToast: MessageToastState?
    var hasLoadedInitialData = false
    var currentAgeInDays = 0
    var errorMessage: String?
    var milestones: [GrowthMilestoneEntry] = []
    var milestoneSheetState: GrowthMilestoneSheetState = .closed
    var milestoneDraft = GrowthMilestoneDraft()

    var isPrecisionVisible: Bool {
        chartInteractionState != .idle
    }
}

enum GrowthAction {
    case onAppear
    case selectMetric(GrowthMetric)
    case toggleAIState
    case tapEntry
    case dismissSheet
    case switchToManualInput
    case switchToRulerInput
    case updateManualInput(String)
    case updateRulerValue(Double)
    case saveRecord
    case undoLastRecord
    case dismissUndo
    case dismissMessage
    case beginScrubbing(locationX: CGFloat, plotWidth: CGFloat)
    case updateScrubbing(locationX: CGFloat, plotWidth: CGFloat)
    case endScrubbing
    case tapAddMilestone
    case tapEditMilestone(GrowthMilestoneEntry)
    case dismissMilestoneSheet
    case updateMilestoneDraft(GrowthMilestoneDraft)
    case saveMilestone
    case deleteMilestone(UUID)
    case undoDeletedMilestone
    case dismissMilestoneUndo
}

struct GrowthMilestoneDraft: Equatable {
    var id: UUID = UUID()
    var templateKey: String?
    var customTitle: String = ""
    var category: GrowthMilestoneCategory = .motor
    var occurredAt: Date = .now
    var note: String = ""
    var imageLocalPath: String?
    var isCustom: Bool = false
}

enum GrowthMilestoneSheetState: Equatable {
    case closed
    case add
    case edit(GrowthMilestoneEntry)

    var isPresented: Bool { self != .closed }
}
