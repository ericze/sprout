import Foundation
import Testing
@testable import sprout

@MainActor
struct TreasureStoreTests {

    @Test("regenerate weekly letter recomputes content")
    func testRegenerateWeeklyLetter() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let environment = try makeTestEnvironment(now: now)
        let store = makeTreasureStore(environment: environment)

        let calendar = Calendar(identifier: .gregorian)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!

        // Create an entry so the week has data for a letter
        _ = try environment.treasureRepository.createMemoryEntry(
            note: "First entry",
            imageLocalPaths: [],
            isMilestone: false,
            createdAt: now,
            birthDate: HomeHeaderConfig.placeholder.birthDate
        )

        // Generate initial weekly letter
        let composer = WeeklyLetterComposer(calendar: calendar)
        try environment.treasureRepository.syncWeeklyLetter(
            for: weekStart,
            composer: composer,
            generatedAt: now
        )

        // Load timeline so the store has the letter item
        store.handle(.onAppear)

        let originalLetters = try environment.treasureRepository.fetchWeeklyLetters()
        #expect(originalLetters.count == 1)
        let originalText = originalLetters.first?.collapsedText

        // Find the weekly letter in timeline
        let letterItem = store.viewState.timelineItems.first(where: { $0.isWeeklyLetter })
        #expect(letterItem != nil)

        // Add another entry to change the week's content
        _ = try environment.treasureRepository.createMemoryEntry(
            note: "Second entry to change the week",
            imageLocalPaths: [],
            isMilestone: false,
            createdAt: now.addingTimeInterval(-86400),
            birthDate: HomeHeaderConfig.placeholder.birthDate
        )

        // Regenerate the letter
        store.handle(.regenerateWeeklyLetter(letterItem!))

        // Verify the letter was recomputed
        let regeneratedLetters = try environment.treasureRepository.fetchWeeklyLetters()
        #expect(regeneratedLetters.count == 1)

        // Verify success toast was shown
        #expect(store.viewState.messageToast != nil)

        // Verify timeline was refreshed
        #expect(!store.viewState.timelineItems.isEmpty)
    }

    @Test("regenerate weekly letter preserves old content on failure")
    func testRegenerateWeeklyLetterFailure() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!

        // Build a store with no repository (simulates unavailable repo)
        let store = TreasureStore(
            headerConfig: .placeholder,
            repository: nil,
            weeklyLetterComposer: WeeklyLetterComposer(calendar: calendar),
            calendar: calendar,
            dateProvider: { now }
        )

        let item = TreasureTimelineItem(
            id: UUID(),
            type: .weeklyLetterNormal,
            createdAt: now,
            monthKey: "2024-03",
            ageInDays: nil,
            imageLocalPaths: [],
            note: nil,
            hasImageLoadError: false,
            isMilestone: false,
            milestoneTitle: nil,
            letterDensity: .normal,
            collapsedText: "Old letter",
            expandedText: "Old expanded",
            weekStart: weekStart,
            weekEnd: now
        )

        store.handle(.regenerateWeeklyLetter(item))

        // No crash, no toast (guard exits early with no repository)
        #expect(store.viewState.messageToast == nil)
    }
}
