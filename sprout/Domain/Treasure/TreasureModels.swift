import CoreGraphics
import Foundation

enum TreasureLimits {
    static let maxImagesPerEntry = 6
}

enum WeeklyLetterDensity: String, Codable, CaseIterable {
    case silent
    case normal
    case dense
}

enum TreasureTimelineItemType: Equatable {
    case memory
    case milestone
    case growthMilestone
    case weeklyLetterSilent
    case weeklyLetterNormal
    case weeklyLetterDense
}

struct TreasureTimelineItem: Identifiable, Equatable {
    let id: UUID
    let type: TreasureTimelineItemType
    let createdAt: Date
    let monthKey: String
    let ageInDays: Int?
    let imageLocalPaths: [String]
    let note: String?
    let hasImageLoadError: Bool
    let isMilestone: Bool
    let milestoneTitle: String?
    let letterDensity: WeeklyLetterDensity?
    let collapsedText: String?
    let expandedText: String?
    let weekStart: Date?
    let weekEnd: Date?

    var isWeeklyLetter: Bool {
        letterDensity != nil
    }

    var canOpenWeeklyLetter: Bool {
        type == .weeklyLetterNormal || type == .weeklyLetterDense
    }

    var isGrowthMilestone: Bool {
        type == .growthMilestone
    }
}

struct TreasureMonthAnchor: Identifiable, Equatable {
    let id: String
    let monthKey: String
    let displayText: String
    let firstTimelineItemID: UUID
}

struct TreasureComposeDraft: Equatable {
    var note: String = ""
    var imageLocalPaths: [String] = []
    var isMilestone = false

    var hasImage: Bool {
        !imageLocalPaths.isEmpty
    }

    var hasText: Bool {
        !note.trimmed.isEmpty
    }

    var hasAnyUserIntent: Bool {
        hasImage || hasText || isMilestone
    }

    var canSave: Bool {
        hasImage || hasText
    }

    mutating func reset() {
        note = ""
        imageLocalPaths = []
        isMilestone = false
    }
}

enum TreasureDataState: Equatable {
    case loading
    case empty
    case lowContent
    case ready
    case error
}

enum TreasureScrollIntentState: Equatable {
    case idle
    case readingDown
    case reversingUp
    case fastScrolling
    case monthScrubbing
}

enum TreasureMonthScrubberState: Equatable {
    case hidden
    case appearing
    case visible
    case dragging
    case fading
    case onboardingNudge
}

enum TreasureComposeState: Equatable {
    case closed
    case opening
    case editingEmpty
    case editingTextOnly
    case editingPhotoOnly
    case editingPhotoAndText
    case editingMilestone
    case confirmingDiscard
    case saving
    case failed

    var isPresented: Bool {
        self != .closed
    }
}

enum TreasureWeeklyLetterViewState: Equatable {
    case collapsed
    case expandedBottomSheet
}

struct TreasureViewState: Equatable {
    var dataState: TreasureDataState = .loading
    var scrollIntentState: TreasureScrollIntentState = .idle
    var monthScrubberState: TreasureMonthScrubberState = .hidden
    var isFloatingAddButtonVisible = true
    var composeState: TreasureComposeState = .closed
    var weeklyLetterViewState: TreasureWeeklyLetterViewState = .collapsed
    var timelineItems: [TreasureTimelineItem] = []
    var monthAnchors: [TreasureMonthAnchor] = []
    var composeDraft = TreasureComposeDraft()
    var selectedWeeklyLetter: TreasureTimelineItem?
    var activeMonthAnchor: TreasureMonthAnchor?
    var undoToast: UndoToastState?
    var messageToast: MessageToastState?
    var scrollTargetID: UUID?
    var errorMessage: String?
    var composeErrorMessage: String?
    var hasLoadedInitialData = false

    var hasVisibleContent: Bool {
        !timelineItems.isEmpty
    }
}

enum TreasureAction {
    case onAppear
    case didScroll(offset: CGFloat, timestamp: TimeInterval)
    case beginScrollInteraction
    case endScrollInteraction
    case tapAddToday
    case dismissCompose
    case confirmDiscard
    case cancelDiscard
    case updateNote(String)
    case toggleMilestone
    case appendImagePaths([String])
    case replaceImagePaths([String])
    case removeImage(at: Int)
    case saveCompose
    case retrySaveCompose
    case dismissComposeError
    case undoLastEntry
    case dismissUndo
    case dismissMessage
    case tapWeeklyLetter(UUID)
    case dismissWeeklyLetter
    case beginMonthScrubbing(height: CGFloat, locationY: CGFloat)
    case updateMonthScrubbing(height: CGFloat, locationY: CGFloat)
    case endMonthScrubbing
}
