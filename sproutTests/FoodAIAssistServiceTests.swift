import Testing
import Foundation
@testable import sprout

struct FoodAIAssistServiceTests {

    @Test("mock service returns valid suggestion")
    func testMockServiceReturnsValidSuggestion() async throws {
        let service = MockFoodAIAssistService()
        let allowedTags = ["Apple", "Banana", "Carrot", "Rice cereal"]

        let result = try await service.suggest(
            imageLocalPath: "/tmp/photo.jpg",
            locale: Locale(identifier: "en"),
            allowedTags: allowedTags,
            knownFoodTags: []
        )

        #expect(result.candidateTags.count == 3)
        #expect(result.candidateTags[0].tag == "Apple")
        #expect(result.confidenceLevel == .high)
        #expect(result.textureStage == "puree")
        #expect(result.noteSuggestion == "Baby enjoyed this!")
    }

    @Test("mock service throws configured error")
    func testMockServiceThrowsError() async {
        struct TestError: Error {}
        let service = MockFoodAIAssistService()
        service.errorToThrow = TestError()

        do {
            _ = try await service.suggest(
                imageLocalPath: "/tmp/photo.jpg",
                locale: Locale(identifier: "en"),
                allowedTags: [],
                knownFoodTags: []
            )
            Issue.record("Expected error to be thrown")
        } catch {
            // Expected
        }
    }

    @Test("mock service returns configured result")
    func testMockServiceReturnsConfiguredResult() async throws {
        let service = MockFoodAIAssistService()
        let customResult = FoodAISuggestionResult(
            candidateTags: [FoodTagCandidate(tag: "Banana", confidence: 0.95)],
            candidateAllergenGroups: [],
            textureStage: "mashed",
            noteSuggestion: nil,
            confidenceLevel: .medium
        )
        service.resultToReturn = customResult

        let result = try await service.suggest(
            imageLocalPath: "/tmp/photo.jpg",
            locale: Locale(identifier: "en"),
            allowedTags: [],
            knownFoodTags: []
        )

        #expect(result == customResult)
        #expect(result.confidenceLevel == .medium)
    }

    @Test("canonicalization filters unknown tags")
    func testCanonicalizationFiltersUnknownTags() throws {
        let catalog = FoodTagCatalog(language: .english)
        let allowedTags = ["Apple", "Banana", "Pumpkin"]

        let result = FoodAISuggestionResult(
            candidateTags: [
                FoodTagCandidate(tag: "Apple", confidence: 0.9),
                FoodTagCandidate(tag: "Mystery Fruit", confidence: 0.8),
                FoodTagCandidate(tag: "Banana", confidence: 0.7),
            ],
            candidateAllergenGroups: [],
            textureStage: nil,
            noteSuggestion: nil,
            confidenceLevel: .high
        )

        let canonicalized = result.canonicalized(with: catalog, allowedTags: allowedTags)

        #expect(canonicalized.candidateTags.count == 2)
        #expect(canonicalized.candidateTags[0].tag == "Apple")
        #expect(canonicalized.candidateTags[1].tag == "Banana")
    }

    @Test("canonicalization resolves aliases")
    func testCanonicalizationResolvesAliases() throws {
        let catalog = FoodTagCatalog(language: .english)
        let allowedTags = ["Apple", "Pumpkin"]

        let result = FoodAISuggestionResult(
            candidateTags: [
                FoodTagCandidate(tag: "Apple puree", confidence: 0.9),
                FoodTagCandidate(tag: "Pumpkin puree", confidence: 0.8),
            ],
            candidateAllergenGroups: [],
            textureStage: nil,
            noteSuggestion: nil,
            confidenceLevel: .high
        )

        let canonicalized = result.canonicalized(with: catalog, allowedTags: allowedTags)

        #expect(canonicalized.candidateTags.count == 2)
        #expect(canonicalized.candidateTags[0].tag == "Apple")
        #expect(canonicalized.candidateTags[1].tag == "Pumpkin")
    }

    @Test("canonicalization resolves Chinese aliases")
    func testCanonicalizationResolvesChineseAliases() throws {
        let catalog = FoodTagCatalog(language: .simplifiedChinese)
        let allowedTags = ["苹果", "南瓜"]

        let result = FoodAISuggestionResult(
            candidateTags: [
                FoodTagCandidate(tag: "苹果泥", confidence: 0.9),
                FoodTagCandidate(tag: "南瓜泥", confidence: 0.8),
            ],
            candidateAllergenGroups: [],
            textureStage: nil,
            noteSuggestion: nil,
            confidenceLevel: .high
        )

        let canonicalized = result.canonicalized(with: catalog, allowedTags: allowedTags)

        #expect(canonicalized.candidateTags.count == 2)
        #expect(canonicalized.candidateTags[0].tag == "苹果")
        #expect(canonicalized.candidateTags[1].tag == "南瓜")
    }

    @Test("duplicate tags are removed keeping highest confidence")
    func testDuplicateTagsRemoved() throws {
        let catalog = FoodTagCatalog(language: .english)
        let allowedTags = ["Apple"]

        let result = FoodAISuggestionResult(
            candidateTags: [
                FoodTagCandidate(tag: "Apple", confidence: 0.7),
                FoodTagCandidate(tag: "Apple puree", confidence: 0.9),
            ],
            candidateAllergenGroups: [],
            textureStage: nil,
            noteSuggestion: nil,
            confidenceLevel: .medium
        )

        let canonicalized = result.canonicalized(with: catalog, allowedTags: allowedTags)

        // Sorted by confidence desc, so "Apple puree" (0.9) comes first and "Apple" (0.7) is deduped
        #expect(canonicalized.candidateTags.count == 1)
        #expect(canonicalized.candidateTags[0].tag == "Apple")
        #expect(canonicalized.candidateTags[0].confidence == 0.9)
    }

    @Test("canonicalization preserves allergen groups and other fields")
    func testCanonicalizationPreservesOtherFields() throws {
        let catalog = FoodTagCatalog(language: .english)
        let allowedTags = ["Egg"]

        let result = FoodAISuggestionResult(
            candidateTags: [FoodTagCandidate(tag: "Egg", confidence: 0.95)],
            candidateAllergenGroups: ["eggs"],
            textureStage: "scrambled",
            noteSuggestion: "Loved it!",
            confidenceLevel: .high
        )

        let canonicalized = result.canonicalized(with: catalog, allowedTags: allowedTags)

        #expect(canonicalized.candidateAllergenGroups == ["eggs"])
        #expect(canonicalized.textureStage == "scrambled")
        #expect(canonicalized.noteSuggestion == "Loved it!")
        #expect(canonicalized.confidenceLevel == .high)
    }
}
