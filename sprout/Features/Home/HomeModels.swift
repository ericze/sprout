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

enum RecordCellInteractionState: Equatable {
    case idle
    case pressing(recordID: UUID)
    case menuTargeted(recordID: UUID)
}

enum RecordInteractionFocusState: Equatable {
    case timelineIdle
    case recordPressed(UUID)
    case contextMenu(UUID)
    case deleteConfirming(UUID)
    case editing(UUID)
}

enum RecordEditorType: String, CaseIterable, Equatable, Identifiable {
    case milk
    case diaper
    case sleep
    case food

    var id: String { rawValue }

    init?(recordType: RecordType) {
        switch recordType {
        case .milk:
            self = .milk
        case .diaper:
            self = .diaper
        case .sleep:
            self = .sleep
        case .food:
            self = .food
        case .height, .weight, .headCircumference:
            return nil
        }
    }
}

enum RecordEditorMode: Equatable {
    case create
    case edit(recordID: UUID)

    var recordID: UUID? {
        switch self {
        case .create:
            nil
        case let .edit(recordID):
            recordID
        }
    }
}

struct RecordEditorRouteState: Equatable, Identifiable {
    let editorType: RecordEditorType
    let mode: RecordEditorMode

    var id: String {
        switch mode {
        case .create:
            "record-editor-\(editorType.rawValue)-create"
        case let .edit(recordID):
            "record-editor-\(editorType.rawValue)-edit-\(recordID.uuidString)"
        }
    }
}

enum ActiveSheet: Equatable, Identifiable {
    case recordEditor(RecordEditorRouteState)
    case sleepControl

    var id: String {
        switch self {
        case let .recordEditor(route):
            route.id
        case .sleepControl:
            "sleep-control"
        }
    }

    var recordEditorRoute: RecordEditorRouteState? {
        guard case let .recordEditor(route) = self else { return nil }
        return route
    }

    var isFoodRecordEditor: Bool {
        guard case let .recordEditor(route) = self else { return false }
        return route.editorType == .food
    }
}

struct RecordDeleteSummary: Equatable, Identifiable {
    let recordID: UUID
    let title: String
    let subtitle: String?
    let timestamp: Date
    let type: RecordType

    var id: UUID { recordID }
}

enum RecordDeleteState: Equatable {
    case idle
    case confirming(summary: RecordDeleteSummary)

    var summary: RecordDeleteSummary? {
        guard case let .confirming(summary) = self else { return nil }
        return summary
    }
}

struct DeletedRecordSnapshot: Equatable {
    let recordID: UUID
    let timestamp: Date
    let type: RecordType
    let value: Double?
    let leftNursingSeconds: Int
    let rightNursingSeconds: Int
    let subType: String?
    let imageURL: String?
    let aiSummary: String?
    let tags: [String]?
    let note: String?
    let message: String
}

enum RecordFeedbackState: Equatable {
    case none
    case message(String)
    case undoDelete(DeletedRecordSnapshot)
    case undoCreate(UndoToastState)

    var undoToast: UndoToastState? {
        switch self {
        case let .undoCreate(toast):
            toast
        case let .undoDelete(snapshot):
            UndoToastState(recordID: snapshot.recordID, message: snapshot.message)
        case .none, .message:
            nil
        }
    }

    var messageText: String? {
        guard case let .message(message) = self else { return nil }
        return message
    }
}

enum RecordMutationState: Equatable {
    case idle
    case savingEdit(recordID: UUID)
    case deleting(recordID: UUID)
    case restoringDeleted(recordID: UUID)

    var isInFlight: Bool {
        self != .idle
    }
}

struct HomeRouteState {
    var activeSheet: ActiveSheet?
    var recordDeleteState: RecordDeleteState = .idle

    var recordEditorRoute: RecordEditorRouteState? {
        activeSheet?.recordEditorRoute
    }
}

struct HomeViewState {
    var todayDisplayItems: [TimelineDisplayItem] = []
    var historyDisplayItems: [TimelineDisplayItem] = []
    var ongoingSleep: SleepSessionState?
    var recordCellInteractionState: RecordCellInteractionState = .idle
    var recordInteractionFocusState: RecordInteractionFocusState = .timelineIdle
    var recordFeedbackState: RecordFeedbackState = .none
    var recordMutationState: RecordMutationState = .idle
    var undoToast: UndoToastState?
    var messageToast: MessageToastState?
    var recentFoodTags: [String] = []
    var knownFoodTags: [String] = []
    var firstTasteFoodTags: [String] = []
    var isLoadingHistory = false
    var hasLoadedInitialData = false
    var hasMoreHistory = true
    var foodAIState: FoodAIState = .idle

    var timelineItems: [TimelineDisplayItem] {
        todayDisplayItems + historyDisplayItems
    }
}

struct FoodFirstTasteHint: Equatable {
    let tags: [String]
    let message: String
}

enum FoodAIState: Equatable {
    case idle
    case loading
    case suggestion(FoodAISuggestionResult)
    case failed(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var hasSuggestion: Bool {
        if case .suggestion = self { return true }
        return false
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
    var babyName: String
    var birthDate: Date
    var babyID: UUID
    var avatarPath: String?

    static let placeholder = HomeHeaderConfig(
        babyName: L10n.text("common.baby.placeholder", en: "Baby", zh: "宝宝"),
        birthDate: Calendar.current.date(byAdding: .day, value: -128, to: .now) ?? .now,
        babyID: UUID()
    )

    static func from(_ baby: BabyProfile?) -> HomeHeaderConfig {
        guard let baby else { return .placeholder }
        return HomeHeaderConfig(babyName: baby.name, birthDate: baby.birthDate, babyID: baby.id, avatarPath: baby.avatarPath)
    }
}
