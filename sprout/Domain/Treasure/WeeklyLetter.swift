import Foundation
import SwiftData

@Model
final class WeeklyLetter {
    @Attribute(.unique) var id: UUID
    var weekStart: Date
    var weekEnd: Date
    var density: WeeklyLetterDensity
    var collapsedText: String
    var expandedText: String
    var languageCode: String?
    var sourceSignature: String?
    var generatedBy: String?
    var generatedAt: Date

    init(
        id: UUID = UUID(),
        weekStart: Date,
        weekEnd: Date,
        density: WeeklyLetterDensity,
        collapsedText: String,
        expandedText: String,
        languageCode: String? = nil,
        sourceSignature: String? = nil,
        generatedBy: String? = nil,
        generatedAt: Date
    ) {
        self.id = id
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.density = density
        self.collapsedText = collapsedText
        self.expandedText = expandedText
        self.languageCode = languageCode
        self.sourceSignature = sourceSignature
        self.generatedBy = generatedBy
        self.generatedAt = generatedAt
    }
}
