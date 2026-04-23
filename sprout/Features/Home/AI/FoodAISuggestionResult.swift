import Foundation

struct FoodAISuggestionResult: Equatable, Sendable {
    let candidateTags: [FoodTagCandidate]
    let candidateAllergenGroups: [String]
    let textureStage: String?
    let noteSuggestion: String?
    let confidenceLevel: FoodAIConfidenceLevel
}

struct FoodTagCandidate: Equatable, Sendable {
    let tag: String
    let confidence: Double
}

enum FoodAIConfidenceLevel: String, Equatable, Sendable {
    case high
    case medium
    case low
}

extension FoodAISuggestionResult {
    /// Canonicalizes raw AI tags using the provided catalog, then filters and deduplicates.
    ///
    /// - Parameters:
    ///   - catalog: The `FoodTagCatalog` used for canonicalization.
    ///   - allowedTags: The set of tags that are valid after canonicalization (strict mode).
    ///     Only tags present in this set after canonicalization are kept.
    /// - Returns: A new result with filtered, deduplicated, confidence-sorted candidates.
    func canonicalized(
        with catalog: FoodTagCatalog,
        allowedTags: [String]
    ) -> FoodAISuggestionResult {
        let allowedSet = Set(allowedTags)
        var seenTags = Set<String>()
        var filteredCandidates: [FoodTagCandidate] = []

        let sortedCandidates = candidateTags.sorted { $0.confidence > $1.confidence }

        for candidate in sortedCandidates {
            let canonical = catalog.canonicalTag(for: candidate.tag)
            guard !canonical.isEmpty else { continue }
            guard allowedSet.contains(canonical) else { continue }
            guard !seenTags.contains(canonical) else { continue }

            seenTags.insert(canonical)
            filteredCandidates.append(FoodTagCandidate(tag: canonical, confidence: candidate.confidence))
        }

        return FoodAISuggestionResult(
            candidateTags: filteredCandidates,
            candidateAllergenGroups: candidateAllergenGroups,
            textureStage: textureStage,
            noteSuggestion: noteSuggestion,
            confidenceLevel: confidenceLevel
        )
    }
}
