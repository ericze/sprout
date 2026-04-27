import Foundation

struct WeeklyDigest: Equatable {
    let weekStart: Date
    let weekEnd: Date
    let memories: [MemoryEntry]
    let milestones: [DigestGrowthMilestone]
    let growthRecordCount: Int
    let firstTasteTags: [String]
    let photoCount: Int
    let textCount: Int
    let memoryMilestoneCount: Int
    let growthMilestoneCount: Int
    let milestoneCount: Int
}

struct DigestGrowthMilestone: Equatable {
    let id: UUID
    let title: String
    let occurredAt: Date
}

struct WeeklyDigestBuilder {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func build(
        entries: [MemoryEntry],
        milestones: [DigestGrowthMilestone],
        growthRecords: [RecordItem],
        weekStart: Date,
        weekEnd: Date
    ) -> WeeklyDigest {
        let rangeEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: weekEnd) ?? weekEnd
        let range = weekStart ... rangeEnd

        let filteredEntries = entries.filter { range.contains($0.createdAt) }
        let filteredMilestones = milestones.filter { range.contains($0.occurredAt) }
        let filteredGrowthRecords = growthRecords.filter { range.contains($0.timestamp) }

        let photoCount = filteredEntries.reduce(into: 0) { count, entry in
            count += entry.imageLocalPaths.count
        }
        let textCount = filteredEntries.filter { entry in
            !(entry.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }.count
        let memoryMilestoneCount = filteredEntries.filter(\.isMilestone).count
        let growthMilestoneCount = filteredMilestones.count
        let milestoneCount = memoryMilestoneCount + growthMilestoneCount

        let firstTasteTags = collectFirstTasteTags(from: growthRecords, in: range)

        return WeeklyDigest(
            weekStart: weekStart,
            weekEnd: weekEnd,
            memories: filteredEntries,
            milestones: filteredMilestones,
            growthRecordCount: filteredGrowthRecords.count,
            firstTasteTags: firstTasteTags,
            photoCount: photoCount,
            textCount: textCount,
            memoryMilestoneCount: memoryMilestoneCount,
            growthMilestoneCount: growthMilestoneCount,
            milestoneCount: milestoneCount
        )
    }

    private func collectFirstTasteTags(from records: [RecordItem], in range: ClosedRange<Date>) -> [String] {
        let foodRecords = records
            .filter { $0.type == RecordType.food.rawValue && range.contains($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }

        var seen = Set<String>()
        var firstTags: [String] = []
        for record in foodRecords {
            guard let tags = record.tags else { continue }
            for tag in tags {
                if seen.insert(tag).inserted {
                    firstTags.append(tag)
                }
            }
        }
        return firstTags
    }
}
