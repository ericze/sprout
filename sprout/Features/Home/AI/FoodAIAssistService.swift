import Foundation

protocol FoodAIAssistService: Sendable {
    func suggest(
        imageLocalPath: String,
        locale: Locale,
        allowedTags: [String],
        knownFoodTags: [String]
    ) async throws -> FoodAISuggestionResult
}
