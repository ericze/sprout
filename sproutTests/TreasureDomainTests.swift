import Foundation
import Testing
@testable import sprout

struct TreasureDomainTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    @Test("Treasure month anchors format correctly in English and Chinese")
    func testMonthAnchorFormatting() throws {
        let aprilDate = makeDate(year: 2026, month: 4, day: 5)
        let mayDate = makeDate(year: 2026, month: 5, day: 2)
        let items = [
            makeTimelineItem(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, createdAt: aprilDate, monthKey: "2026-04"),
            makeTimelineItem(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, createdAt: mayDate, monthKey: "2026-05"),
        ]

        let englishBuilder = TreasureMonthAnchorBuilder(
            calendar: Self.calendar,
            localizationService: LocalizationService(
                locale: Locale(identifier: "en_US_POSIX"),
                language: .english
            )
        )
        let englishAnchors = englishBuilder.build(from: items)
        #expect(englishAnchors.count == 2)
        #expect(englishAnchors[0].displayText == "April 2026")
        #expect(englishAnchors[1].displayText == "May 2026")
        #expect(englishAnchors[0].firstTimelineItemID == items[0].id)

        let chineseBuilder = TreasureMonthAnchorBuilder(
            calendar: Self.calendar,
            localizationService: LocalizationService(
                locale: Locale(identifier: "zh-Hans"),
                language: .simplifiedChinese
            )
        )
        let chineseAnchors = chineseBuilder.build(from: items)
        #expect(chineseAnchors.count == 2)
        #expect(chineseAnchors[0].displayText == "2026年4月")
        #expect(chineseAnchors[1].displayText == "2026年5月")
    }

    @Test("Weekly letters generate in both supported languages")
    func testWeeklyLetterComposerGeneratesLetters() throws {
        let weekStart = makeDate(year: 2026, month: 4, day: 6)
        let weekEnd = makeDate(year: 2026, month: 4, day: 12)
        let generatedAt = makeDate(year: 2026, month: 4, day: 12)
        let entries = [
            MemoryEntry(
                createdAt: makeDate(year: 2026, month: 4, day: 7),
                ageInDays: 90,
                imageLocalPaths: ["photo-a.jpg"],
                note: nil,
                isMilestone: false
            ),
            MemoryEntry(
                createdAt: makeDate(year: 2026, month: 4, day: 8),
                ageInDays: 91,
                imageLocalPaths: [],
                note: "First spoonful",
                isMilestone: false
            ),
        ]

        let englishComposer = WeeklyLetterComposer(calendar: Self.calendar, language: .english)
        let englishLetter = englishComposer.compose(
            entries: entries,
            weekStart: weekStart,
            weekEnd: weekEnd,
            generatedAt: generatedAt
        )
        #expect(englishLetter != nil)
        let englishLetterUnwrapped = englishLetter!
        #expect(englishLetterUnwrapped.density == .normal)
        #expect(englishLetterUnwrapped.collapsedText == "A letter arrived for this week.")
        #expect(englishLetterUnwrapped.expandedText.contains("2 memories this week"))

        let chineseComposer = WeeklyLetterComposer(calendar: Self.calendar, language: .simplifiedChinese)
        let chineseLetter = chineseComposer.compose(
            entries: entries,
            weekStart: weekStart,
            weekEnd: weekEnd,
            generatedAt: generatedAt
        )
        #expect(chineseLetter != nil)
        let chineseLetterUnwrapped = chineseLetter!
        #expect(chineseLetterUnwrapped.density == .normal)
        #expect(chineseLetterUnwrapped.collapsedText == "时间寄来了一封这一周的信。")
        #expect(chineseLetterUnwrapped.expandedText.contains("2 条记忆"))
    }

    @Test("Weekly letters generate for a single quiet entry")
    func testWeeklyLetterComposerGeneratesSilentLetter() throws {
        let weekStart = makeDate(year: 2026, month: 4, day: 6)
        let weekEnd = makeDate(year: 2026, month: 4, day: 12)
        let generatedAt = makeDate(year: 2026, month: 4, day: 12)
        let entries = [
            MemoryEntry(
                createdAt: makeDate(year: 2026, month: 4, day: 7),
                ageInDays: 90,
                imageLocalPaths: [],
                note: nil,
                isMilestone: false
            ),
        ]

        let composer = WeeklyLetterComposer(calendar: Self.calendar, language: .english)
        let letter = composer.compose(
            entries: entries,
            weekStart: weekStart,
            weekEnd: weekEnd,
            generatedAt: generatedAt
        )

        #expect(letter != nil)
        let unwrapped = letter!
        #expect(unwrapped.density == .silent)
        #expect(unwrapped.collapsedText == "A quiet week.")
        #expect(unwrapped.expandedText.contains("One memory, quietly kept."))
    }

    @Test("Weekly letters return nil for empty input")
    func testWeeklyLetterComposerReturnsNilForEmptyInput() {
        let composer = WeeklyLetterComposer(calendar: Self.calendar, language: .english)

        let letter = composer.compose(
            entries: [],
            weekStart: makeDate(year: 2026, month: 4, day: 6),
            weekEnd: makeDate(year: 2026, month: 4, day: 12),
            generatedAt: makeDate(year: 2026, month: 4, day: 12)
        )

        #expect(letter == nil)
    }

    @Test("Weekly letter includes growth milestone highlight in English")
    func testWeeklyLetterIncludesGrowthMilestoneHighlightEnglish() throws {
        let weekStart = makeDate(year: 2026, month: 4, day: 6)
        let weekEnd = makeDate(year: 2026, month: 4, day: 12)
        let generatedAt = makeDate(year: 2026, month: 4, day: 12)
        let entries = [
            MemoryEntry(
                createdAt: makeDate(year: 2026, month: 4, day: 7),
                ageInDays: 90,
                imageLocalPaths: [],
                note: "A lovely day",
                isMilestone: false
            ),
        ]
        let milestones = [
            GrowthMilestoneEntry(
                title: "First roll",
                category: "motor",
                occurredAt: makeDate(year: 2026, month: 4, day: 8)
            ),
        ]

        let composer = WeeklyLetterComposer(calendar: Self.calendar, language: .english)
        let letter = try #require(composer.compose(
            entries: entries,
            milestones: milestones,
            weekStart: weekStart,
            weekEnd: weekEnd,
            generatedAt: generatedAt
        ))

        #expect(letter.density == .dense)
        #expect(letter.expandedText.contains("First roll"))
        #expect(letter.expandedText.contains("milestone"))
    }

    @Test("Weekly letter includes growth milestone highlight in Chinese")
    func testWeeklyLetterIncludesGrowthMilestoneHighlightChinese() throws {
        let weekStart = makeDate(year: 2026, month: 4, day: 6)
        let weekEnd = makeDate(year: 2026, month: 4, day: 12)
        let generatedAt = makeDate(year: 2026, month: 4, day: 12)
        let entries = [
            MemoryEntry(
                createdAt: makeDate(year: 2026, month: 4, day: 7),
                ageInDays: 90,
                imageLocalPaths: [],
                note: "今天很开心",
                isMilestone: false
            ),
        ]
        let milestones = [
            GrowthMilestoneEntry(
                title: "第一次翻身",
                category: "motor",
                occurredAt: makeDate(year: 2026, month: 4, day: 8)
            ),
        ]

        let composer = WeeklyLetterComposer(calendar: Self.calendar, language: .simplifiedChinese)
        let letter = try #require(composer.compose(
            entries: entries,
            milestones: milestones,
            weekStart: weekStart,
            weekEnd: weekEnd,
            generatedAt: generatedAt
        ))

        #expect(letter.density == .dense)
        #expect(letter.expandedText.contains("成长里程碑"))
        #expect(letter.expandedText.contains("第一次翻身"))
    }

    private func makeTimelineItem(id: UUID, createdAt: Date, monthKey: String) -> TreasureTimelineItem {
        TreasureTimelineItem(
            id: id,
            type: .memory,
            createdAt: createdAt,
            monthKey: monthKey,
            ageInDays: nil,
            imageLocalPaths: [],
            note: "note",
            hasImageLoadError: false,
            isMilestone: false,
            milestoneTitle: nil,
            letterDensity: nil,
            collapsedText: nil,
            expandedText: nil,
            weekStart: nil,
            weekEnd: nil
        )
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
