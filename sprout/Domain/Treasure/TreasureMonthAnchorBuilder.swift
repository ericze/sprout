import Foundation

struct TreasureMonthAnchorBuilder {
    private let calendar: Calendar
    private let localizationService: LocalizationService

    init(
        calendar: Calendar = .current,
        localizationService: LocalizationService = .current
    ) {
        self.calendar = calendar
        self.localizationService = localizationService
    }

    func build(from items: [TreasureTimelineItem]) -> [TreasureMonthAnchor] {
        var seenMonthKeys = Set<String>()
        var anchors: [TreasureMonthAnchor] = []

        for item in items {
            guard !seenMonthKeys.contains(item.monthKey) else { continue }
            seenMonthKeys.insert(item.monthKey)
            anchors.append(
                TreasureMonthAnchor(
                    id: item.monthKey,
                    monthKey: item.monthKey,
                    displayText: displayText(for: item.createdAt),
                    firstTimelineItemID: item.id
                )
            )
        }

        return anchors
    }

    private func displayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localizationService.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        switch localizationService.language {
        case .english:
            formatter.dateFormat = "MMMM yyyy"
        case .simplifiedChinese:
            formatter.dateFormat = "yyyy年M月"
        }

        return formatter.string(from: date)
    }
}
