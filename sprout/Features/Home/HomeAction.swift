import Foundation

enum HomeAction {
    case onAppear
    case tapMilkEntry
    case tapDiaperEntry
    case tapSleepEntry
    case tapFoodEntry
    case tapOngoingSleep
    case tapTimelineRecord(UUID)
    case longPressTimelineRecord(UUID)
    case releaseTimelineRecordPress
    case dismissRecordContextMenu
    case selectRecordContextEdit(UUID)
    case selectRecordContextDelete(UUID)
    case cancelDeleteRecord
    case confirmDeleteRecord
    case dismissSheet
    case dismissRecordEditor
    case selectMilkTab(MilkTab)
    case tapNursingSide(NursingSide)
    case selectBottlePreset(Int)
    case adjustBottleAmount(Int)
    case saveFeedingRecord
    case saveDiaper(DiaperSubtype)
    case finishSleep
    case saveFood
    case saveRecordEdits
    case undoLastRecord
    case undoDeletedRecord
    case dismissUndo
    case dismissMessage
    case loadMoreIfNeeded(UUID)
    case tapFoodAISuggest
    case applyFoodAISuggestion
    case dismissFoodAISuggestion
    case retryFoodAISuggestion
}
