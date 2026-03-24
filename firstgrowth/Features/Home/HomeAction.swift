import Foundation

enum HomeAction {
    case onAppear
    case selectModule(HomeModule)
    case tapMilkEntry
    case tapDiaperEntry
    case tapSleepEntry
    case tapFoodEntry
    case tapOngoingSleep
    case dismissSheet
    case selectMilkTab(MilkTab)
    case tapNursingSide(NursingSide)
    case selectBottlePreset(Int)
    case adjustBottleAmount(Int)
    case saveFeedingRecord
    case saveDiaper(DiaperSubtype)
    case finishSleep
    case saveFood
    case undoLastRecord
    case dismissUndo
    case loadMoreIfNeeded(UUID)
}
