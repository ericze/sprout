import Foundation

enum HomeModule: String, CaseIterable, Identifiable {
    case record
    case growth
    case collection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .record:
            "记录"
        case .growth:
            "成长"
        case .collection:
            "珍藏"
        }
    }
}

enum ActiveSheet: String, Identifiable {
    case milk
    case diaper
    case food
    case sleepControl

    var id: String { rawValue }
}

struct HomeRouteState {
    var currentModule: HomeModule = .record
    var activeSheet: ActiveSheet?
}

struct HomeViewState {
    var todayDisplayItems: [TimelineDisplayItem] = []
    var historyDisplayItems: [TimelineDisplayItem] = []
    var ongoingSleep: SleepSessionState?
    var undoToast: UndoToastState?
    var recentFoodTags: [String] = []
    var isLoadingHistory = false
    var hasLoadedInitialData = false
    var hasMoreHistory = true

    var timelineItems: [TimelineDisplayItem] {
        todayDisplayItems + historyDisplayItems
    }
}

struct FoodDraftState {
    var selectedTags: [String] = []
    var note: String = ""
    var selectedImagePath: String?

    var hasContent: Bool {
        !selectedTags.isEmpty || !note.trimmed.isEmpty || selectedImagePath != nil
    }
}

struct UndoToastState: Equatable {
    let recordID: UUID
    let message: String
}

struct HomeHeaderConfig: Equatable {
    let babyName: String
    let birthDate: Date

    static let placeholder = HomeHeaderConfig(
        babyName: "宝宝",
        birthDate: Calendar.current.date(byAdding: .day, value: -128, to: .now) ?? .now
    )
}
