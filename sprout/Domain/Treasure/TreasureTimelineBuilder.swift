import Foundation

struct TreasureTimelineBuilder {
    private let calendar: Calendar
    private let fileManager: FileManager

    init(calendar: Calendar = .current, fileManager: FileManager = .default) {
        self.calendar = calendar
        self.fileManager = fileManager
    }

    func makeTimelineItems(
        entries: [MemoryEntry],
        weeklyLetters: [WeeklyLetter],
        milestones: [GrowthMilestoneEntry] = []
    ) -> [TreasureTimelineItem] {
        let memoryItems = entries.compactMap(makeMemoryItem)
        let letterItems = weeklyLetters.map(makeWeeklyLetterItem)
        let milestoneItems = milestones.map(makeGrowthMilestoneItem)
        return (memoryItems + letterItems + milestoneItems).sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString > rhs.id.uuidString
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func makeMemoryItem(entry: MemoryEntry) -> TreasureTimelineItem? {
        let note = entry.note?.trimmed.nilIfEmpty
        let candidatePaths = normalizedImageLocalPaths(for: entry)
        let readablePaths = candidatePaths.filter { fileManager.fileExists(atPath: $0) }
        let hasImageLoadError = !candidatePaths.isEmpty && readablePaths.count != candidatePaths.count

        guard !readablePaths.isEmpty || note != nil else {
            return nil
        }

        return TreasureTimelineItem(
            id: entry.id,
            type: entry.isMilestone ? .milestone : .memory,
            createdAt: entry.createdAt,
            monthKey: monthKey(for: entry.createdAt),
            ageInDays: entry.ageInDays,
            imageLocalPaths: readablePaths,
            note: note,
            hasImageLoadError: hasImageLoadError,
            isMilestone: entry.isMilestone,
            milestoneTitle: nil,
            letterDensity: nil,
            collapsedText: nil,
            expandedText: nil,
            weekStart: nil,
            weekEnd: nil
        )
    }

    private func makeWeeklyLetterItem(letter: WeeklyLetter) -> TreasureTimelineItem {
        let displayDate = endOfDay(for: letter.weekEnd)
        let type: TreasureTimelineItemType
        switch letter.density {
        case .silent:
            type = .weeklyLetterSilent
        case .normal:
            type = .weeklyLetterNormal
        case .dense:
            type = .weeklyLetterDense
        }

        return TreasureTimelineItem(
            id: letter.id,
            type: type,
            createdAt: displayDate,
            monthKey: monthKey(for: displayDate),
            ageInDays: nil,
            imageLocalPaths: [],
            note: nil,
            hasImageLoadError: false,
            isMilestone: false,
            milestoneTitle: nil,
            letterDensity: letter.density,
            collapsedText: letter.collapsedText,
            expandedText: letter.expandedText,
            weekStart: letter.weekStart,
            weekEnd: letter.weekEnd
        )
    }

    private func makeGrowthMilestoneItem(milestone: GrowthMilestoneEntry) -> TreasureTimelineItem {
        let imageLocalPaths: [String] = {
            guard let path = milestone.imageLocalPath else { return [] }
            return fileManager.fileExists(atPath: path) ? [path] : []
        }()

        return TreasureTimelineItem(
            id: milestone.id,
            type: .growthMilestone,
            createdAt: milestone.occurredAt,
            monthKey: monthKey(for: milestone.occurredAt),
            ageInDays: nil,
            imageLocalPaths: imageLocalPaths,
            note: milestone.note,
            hasImageLoadError: milestone.imageLocalPath != nil && imageLocalPaths.isEmpty,
            isMilestone: false,
            milestoneTitle: milestone.title,
            letterDensity: nil,
            collapsedText: nil,
            expandedText: nil,
            weekStart: nil,
            weekEnd: nil
        )
    }

    private func monthKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 1
        return String(format: "%04d-%02d", year, month)
    }

    private func endOfDay(for date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }

    private func normalizedImageLocalPaths(for entry: MemoryEntry) -> [String] {
        entry.imageLocalPaths
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
