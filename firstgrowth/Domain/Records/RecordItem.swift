import Foundation
import SwiftData

@Model
final class RecordItem {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var type: String
    var value: Double?
    var leftNursingSeconds: Int
    var rightNursingSeconds: Int
    var subType: String?
    var imageURL: String?
    var aiSummary: String?
    var tags: [String]?
    var note: String?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        type: String,
        value: Double? = nil,
        leftNursingSeconds: Int = 0,
        rightNursingSeconds: Int = 0,
        subType: String? = nil,
        imageURL: String? = nil,
        aiSummary: String? = nil,
        tags: [String]? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.value = value
        self.leftNursingSeconds = leftNursingSeconds
        self.rightNursingSeconds = rightNursingSeconds
        self.subType = subType
        self.imageURL = imageURL
        self.aiSummary = aiSummary
        self.tags = tags
        self.note = note
    }
}

extension RecordItem {
    var recordType: RecordType? {
        RecordType(rawValue: type)
    }

    var bottleAmountMl: Int {
        guard let value else { return 0 }
        return max(Int(value.rounded(.towardZero)), 0)
    }

    var totalNursingSeconds: Int {
        max(leftNursingSeconds, 0) + max(rightNursingSeconds, 0)
    }

    var diaperType: DiaperSubtype? {
        guard let subType else { return nil }
        return DiaperSubtype(rawValue: subType)
    }
}
