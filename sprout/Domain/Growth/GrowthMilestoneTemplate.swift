import Foundation

enum GrowthMilestoneCategory: String, CaseIterable, Sendable {
    case motor = "motor"
    case language = "language"
    case social = "social"
    case cognitive = "cognitive"
}

enum GrowthMilestoneTemplate: String, CaseIterable, Sendable {
    case firstSmile = "first_smile"
    case firstLaugh = "first_laugh"
    case firstRoll = "first_roll"
    case firstSit = "first_sit"
    case firstCrawl = "first_crawl"
    case firstStand = "first_stand"
    case firstStep = "first_step"
    case firstWord = "first_word"
    case firstTooth = "first_tooth"

    var title: String {
        rawValue
    }

    var category: GrowthMilestoneCategory {
        switch self {
        case .firstSmile:
            return .social
        case .firstLaugh:
            return .social
        case .firstRoll:
            return .motor
        case .firstSit:
            return .motor
        case .firstCrawl:
            return .motor
        case .firstStand:
            return .motor
        case .firstStep:
            return .motor
        case .firstWord:
            return .language
        case .firstTooth:
            return .cognitive
        }
    }
}
