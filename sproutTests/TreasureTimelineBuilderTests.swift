import Foundation
import Testing
@testable import sprout

struct TreasureTimelineBuilderTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    @Test("timeline merges growth milestones with memory entries and weekly letters")
    func timelineMergesGrowthMilestones() throws {
        let builder = TreasureTimelineBuilder(calendar: Self.calendar)

        let olderDate = makeDate(year: 2026, month: 3, day: 1)
        let middleDate = makeDate(year: 2026, month: 3, day: 10)
        let newerDate = makeDate(year: 2026, month: 3, day: 20)

        let memoryEntry = MemoryEntry(
            createdAt: middleDate,
            ageInDays: 42,
            imageLocalPaths: [],
            note: "Baby smiled",
            isMilestone: false
        )

        let milestone = GrowthMilestoneEntry(
            title: "First Smile",
            category: "social",
            occurredAt: newerDate,
            createdAt: newerDate
        )

        let weeklyLetter = WeeklyLetter(
            weekStart: olderDate,
            weekEnd: makeDate(year: 2026, month: 3, day: 7),
            density: .normal,
            collapsedText: "A letter arrived.",
            expandedText: "2 memories this week.",
            generatedAt: olderDate
        )

        let items = builder.makeTimelineItems(
            entries: [memoryEntry],
            weeklyLetters: [weeklyLetter],
            milestones: [milestone]
        )

        #expect(items.count == 3)

        // Reverse-chronological order: milestone (Mar 20), memory (Mar 10), letter (Mar 7 end-of-day)
        #expect(items[0].isGrowthMilestone == true)
        #expect(items[0].milestoneTitle == "First Smile")
        #expect(items[1].type == .memory)
        #expect(items[2].isWeeklyLetter == true)

        // Verify dates are descending
        #expect(items[0].createdAt >= items[1].createdAt)
        #expect(items[1].createdAt >= items[2].createdAt)
    }

    @Test("growth milestones use .growthMilestone type with correct metadata")
    func growthMilestoneTypeAndMetadata() throws {
        let builder = TreasureTimelineBuilder(calendar: Self.calendar)

        let occurredAt = makeDate(year: 2026, month: 4, day: 15)
        let milestone = GrowthMilestoneEntry(
            title: "First Steps",
            category: "motor",
            occurredAt: occurredAt,
            note: "Took 3 steps!",
            createdAt: occurredAt
        )

        let items = builder.makeTimelineItems(
            entries: [],
            weeklyLetters: [],
            milestones: [milestone]
        )

        #expect(items.count == 1)
        let item = items[0]
        #expect(item.type == .growthMilestone)
        #expect(item.isGrowthMilestone == true)
        #expect(item.milestoneTitle == "First Steps")
        #expect(item.note == "Took 3 steps!")
        #expect(item.isMilestone == false)
    }

    @Test("legacy isMilestone entries still render as .milestone type")
    func legacyMilestoneEntriesStillRender() throws {
        let builder = TreasureTimelineBuilder(calendar: Self.calendar)

        let entry = MemoryEntry(
            createdAt: makeDate(year: 2026, month: 2, day: 1),
            ageInDays: 30,
            imageLocalPaths: [],
            note: "Legacy milestone",
            isMilestone: true
        )

        let items = builder.makeTimelineItems(
            entries: [entry],
            weeklyLetters: [],
            milestones: []
        )

        #expect(items.count == 1)
        #expect(items[0].type == .milestone)
        #expect(items[0].isMilestone == true)
        #expect(items[0].isGrowthMilestone == false)
    }

    @Test("empty milestones array produces same results as omitting it")
    func emptyMilestonesNoEffect() throws {
        let builder = TreasureTimelineBuilder(calendar: Self.calendar)

        let entry = MemoryEntry(
            createdAt: makeDate(year: 2026, month: 4, day: 1),
            ageInDays: 10,
            imageLocalPaths: [],
            note: "A note",
            isMilestone: false
        )

        let withEmpty = builder.makeTimelineItems(
            entries: [entry],
            weeklyLetters: [],
            milestones: []
        )
        let withoutParam = builder.makeTimelineItems(
            entries: [entry],
            weeklyLetters: []
        )

        #expect(withEmpty == withoutParam)
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Self.calendar
        components.timeZone = Self.calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Self.calendar.date(from: components)!
    }
}
