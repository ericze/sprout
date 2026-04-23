import Foundation

final class MockFoodAIAssistService: FoodAIAssistService, @unchecked Sendable {
    var resultToReturn: FoodAISuggestionResult?
    var errorToThrow: Error?

    func suggest(
        imageLocalPath: String,
        locale: Locale,
        allowedTags: [String],
        knownFoodTags: [String]
    ) async throws -> FoodAISuggestionResult {
        if let error = errorToThrow { throw error }
        return resultToReturn ?? FoodAISuggestionResult(
            candidateTags: allowedTags.prefix(3).map { FoodTagCandidate(tag: $0, confidence: 0.9) },
            candidateAllergenGroups: [],
            textureStage: "puree",
            noteSuggestion: "Baby enjoyed this!",
            confidenceLevel: .high
        )
    }
}
