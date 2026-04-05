import Foundation

enum HomeModule: String, CaseIterable, Identifiable {
    case record
    case growth
    case collection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .record:
            String(localized: "module.record.title")
        case .growth:
            String(localized: "module.growth.title")
        case .collection:
            String(localized: "module.collection.title")
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
    var activeSheet: ActiveSheet?
}

struct HomeViewState {
    var todayDisplayItems: [TimelineDisplayItem] = []
    var historyDisplayItems: [TimelineDisplayItem] = []
    var ongoingSleep: SleepSessionState?
    var undoToast: UndoToastState?
    var recentFoodTags: [String] = []
    var knownFoodTags: [String] = []
    var firstTasteFoodTags: [String] = []
    var isLoadingHistory = false
    var hasLoadedInitialData = false
    var hasMoreHistory = true

    var timelineItems: [TimelineDisplayItem] {
        todayDisplayItems + historyDisplayItems
    }
}

struct FoodFirstTasteHint: Equatable {
    let tags: [String]
    let message: String
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
    var babyName: String
    var birthDate: Date

    static let placeholder = HomeHeaderConfig(
        babyName: L10n.text("common.baby.placeholder", en: "Baby", zh: "宝宝"),
        birthDate: Calendar.current.date(byAdding: .day, value: -128, to: .now) ?? .now
    )

    static func from(_ baby: BabyProfile?) -> HomeHeaderConfig {
        guard let baby else { return .placeholder }
        return HomeHeaderConfig(babyName: baby.name, birthDate: baby.birthDate)
    }
}
