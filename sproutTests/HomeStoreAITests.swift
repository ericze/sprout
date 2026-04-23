import Testing
import Foundation
@testable import sprout

@MainActor
struct HomeStoreAITests {

    private func makeStoreWithMockAI(
        result: FoodAISuggestionResult? = nil,
        error: Error? = nil
    ) throws -> (HomeStore, MockFoodAIAssistService) {
        let mockService = MockFoodAIAssistService()
        mockService.resultToReturn = result
        mockService.errorToThrow = error

        let localizationService = LocalizationService(
            bundle: .main,
            locale: Locale(identifier: "en"),
            language: .english
        )
        let store = HomeStore(
            headerConfig: .placeholder,
            localizationService: localizationService,
            calendar: Calendar(identifier: .gregorian),
            dateProvider: { Date() }
        )
        store.configure(aiService: mockService)
        return (store, mockService)
    }

    @Test("AI suggestion writes tags to draft")
    func testAISuggestionWritesTagsToDraft() async throws {
        let result = FoodAISuggestionResult(
            candidateTags: [
                FoodTagCandidate(tag: "Apple", confidence: 0.9),
                FoodTagCandidate(tag: "Banana", confidence: 0.8),
            ],
            candidateAllergenGroups: [],
            textureStage: "puree",
            noteSuggestion: "Baby loved it!",
            confidenceLevel: .high
        )
        let (store, _) = try makeStoreWithMockAI(result: result)

        store.foodDraft.selectedImagePath = "/tmp/test_photo.jpg"
        store.handle(.tapFoodAISuggest)

        // Wait for async suggestion to complete
        try await Task.sleep(for: .milliseconds(200))

        guard case .suggestion = store.viewState.foodAIState else {
            Issue.record("Expected suggestion state, got \(store.viewState.foodAIState)")
            return
        }

        store.handle(.applyFoodAISuggestion)

        #expect(store.foodDraft.selectedTags.contains("Apple"))
        #expect(store.foodDraft.selectedTags.contains("Banana"))
        #expect(store.foodDraft.note == "Baby loved it!")
        #expect(store.viewState.foodAIState == .idle)
    }

    @Test("AI failure preserves draft content")
    func testAIFailurePreservesDraft() async throws {
        struct TestError: Error {}
        let (store, _) = try makeStoreWithMockAI(error: TestError())

        store.foodDraft.selectedTags = ["Existing"]
        store.foodDraft.note = "Existing note"
        store.foodDraft.selectedImagePath = "/tmp/test_photo.jpg"

        store.handle(.tapFoodAISuggest)

        // Wait for async failure to complete
        try await Task.sleep(for: .milliseconds(200))

        guard case .failed = store.viewState.foodAIState else {
            Issue.record("Expected failed state, got \(store.viewState.foodAIState)")
            return
        }

        #expect(store.foodDraft.selectedTags == ["Existing"])
        #expect(store.foodDraft.note == "Existing note")
    }

    @Test("AI note suggestion does not overwrite existing note")
    func testAINoteDoesNotOverwrite() async throws {
        let result = FoodAISuggestionResult(
            candidateTags: [
                FoodTagCandidate(tag: "Apple", confidence: 0.9),
            ],
            candidateAllergenGroups: [],
            textureStage: nil,
            noteSuggestion: "AI suggested note",
            confidenceLevel: .high
        )
        let (store, _) = try makeStoreWithMockAI(result: result)

        store.foodDraft.note = "User's existing note"
        store.foodDraft.selectedImagePath = "/tmp/test_photo.jpg"

        store.handle(.tapFoodAISuggest)

        try await Task.sleep(for: .milliseconds(200))

        guard case .suggestion = store.viewState.foodAIState else {
            Issue.record("Expected suggestion state, got \(store.viewState.foodAIState)")
            return
        }

        store.handle(.applyFoodAISuggestion)

        #expect(store.foodDraft.note == "User's existing note")
        #expect(store.foodDraft.selectedTags.contains("Apple"))
    }

    @Test("AI suggestion with no image does nothing")
    func testAINoImageFails() throws {
        let (store, _) = try makeStoreWithMockAI()

        store.foodDraft.selectedImagePath = nil
        store.handle(.tapFoodAISuggest)

        guard case .failed = store.viewState.foodAIState else {
            Issue.record("Expected failed state when no image, got \(store.viewState.foodAIState)")
            return
        }
    }

    @Test("dismiss AI suggestion resets state")
    func testDismissAISuggestion() async throws {
        let result = FoodAISuggestionResult(
            candidateTags: [FoodTagCandidate(tag: "Apple", confidence: 0.9)],
            candidateAllergenGroups: [],
            textureStage: nil,
            noteSuggestion: nil,
            confidenceLevel: .high
        )
        let (store, _) = try makeStoreWithMockAI(result: result)

        store.foodDraft.selectedImagePath = "/tmp/test_photo.jpg"
        store.handle(.tapFoodAISuggest)

        try await Task.sleep(for: .milliseconds(200))

        guard case .suggestion = store.viewState.foodAIState else {
            Issue.record("Expected suggestion state")
            return
        }

        store.handle(.dismissFoodAISuggestion)

        #expect(store.viewState.foodAIState == .idle)
        #expect(store.foodDraft.selectedTags.isEmpty)
    }

    @Test("retry triggers new suggestion")
    func testRetryFoodAISuggestion() async throws {
        let result = FoodAISuggestionResult(
            candidateTags: [FoodTagCandidate(tag: "Banana", confidence: 0.9)],
            candidateAllergenGroups: [],
            textureStage: nil,
            noteSuggestion: nil,
            confidenceLevel: .high
        )
        let (store, _) = try makeStoreWithMockAI(result: result)

        store.foodDraft.selectedImagePath = "/tmp/test_photo.jpg"
        store.viewState.foodAIState = .failed("previous error")

        store.handle(.retryFoodAISuggestion)

        #expect(store.viewState.foodAIState.isLoading)

        try await Task.sleep(for: .milliseconds(200))

        guard case .suggestion(let retryResult) = store.viewState.foodAIState else {
            Issue.record("Expected suggestion state after retry")
            return
        }

        #expect(retryResult.candidateTags.first?.tag == "Banana")
    }
}
