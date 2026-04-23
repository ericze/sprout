import Foundation

enum RecordType: String, Codable, CaseIterable {
    case milk
    case diaper
    case sleep
    case food
    case height
    case weight
    case headCircumference
}

enum DiaperSubtype: String, Codable, CaseIterable {
    case pee
    case poop
    case both

    var localizationKey: String {
        switch self {
        case .pee:
            "timeline.diaper.pee"
        case .poop:
            "timeline.diaper.poop"
        case .both:
            "timeline.diaper.both"
        }
    }
}

enum TimelineCardStyle: Equatable {
    case standard
    case foodPhoto
}

enum RecordIcon: Equatable {
    case milk
    case diaper
    case sleep
    case food
    case height
    case weight
    case headCircumference

    var systemName: String {
        switch self {
        case .milk:
            "drop.fill"
        case .diaper:
            "circle.grid.2x2.fill"
        case .sleep:
            "moon.zzz.fill"
        case .food:
            "fork.knife.circle.fill"
        case .height:
            "ruler"
        case .weight:
            "scalemass"
        case .headCircumference:
            "circle.circle"
        }
    }
}
