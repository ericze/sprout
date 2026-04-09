import Foundation
import SwiftData

@Model
final class RecordItem {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var timestamp: Date
    var type: String
    var value: Double?
    var leftNursingSeconds: Int
    var rightNursingSeconds: Int
    var subType: String?
    var imageURL: String?
    var remoteImagePath: String?
    var remoteVersion: Int64?
    var syncStateRaw: String
    var aiSummary: String?
    var tags: [String]?
    var note: String?

    init(
        id: UUID = UUID(),
        babyID: UUID = UUID(),
        timestamp: Date,
        type: String,
        value: Double? = nil,
        leftNursingSeconds: Int = 0,
        rightNursingSeconds: Int = 0,
        subType: String? = nil,
        imageURL: String? = nil,
        remoteImagePath: String? = nil,
        remoteVersion: Int64? = nil,
        syncStateRaw: String = SyncState.pendingUpsert.rawValue,
        aiSummary: String? = nil,
        tags: [String]? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.babyID = babyID
        self.timestamp = timestamp
        self.type = type
        self.value = value
        self.leftNursingSeconds = leftNursingSeconds
        self.rightNursingSeconds = rightNursingSeconds
        self.subType = subType
        self.imageURL = imageURL
        self.remoteImagePath = remoteImagePath
        self.remoteVersion = remoteVersion
        self.syncStateRaw = syncStateRaw
        self.aiSummary = aiSummary
        self.tags = tags
        self.note = note
    }
}

/// The minimal persisted data required to recreate a deleted home record.
struct RecordRecoverySnapshot: Equatable {
    let recordID: UUID
    let timestamp: Date
    let type: RecordType
    let value: Double?
    let leftNursingSeconds: Int
    let rightNursingSeconds: Int
    let subType: String?
    let imageURL: String?
    let aiSummary: String?
    let tags: [String]?
    let note: String?
}

extension RecordItem {
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pendingUpsert }
        set { syncStateRaw = newValue.rawValue }
    }

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

    var sleepEndedAt: Date? {
        guard recordType == .sleep, let value else { return nil }
        return timestamp.addingTimeInterval(value)
    }

    var recoverySnapshot: RecordRecoverySnapshot {
        RecordRecoverySnapshot(
            recordID: id,
            timestamp: timestamp,
            type: recordType ?? .milk,
            value: value,
            leftNursingSeconds: leftNursingSeconds,
            rightNursingSeconds: rightNursingSeconds,
            subType: subType,
            imageURL: imageURL,
            aiSummary: aiSummary,
            tags: tags,
            note: note
        )
    }
}
