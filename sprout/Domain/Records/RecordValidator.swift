import Foundation

enum RecordValidationError: Error, Equatable {
    case invalidType(String)
    case missingPositiveValue(RecordType)
    case invalidDiaperSubtype(String?)
    case invalidSleepRange
    case emptyFood
}

struct RecordValidator {
    nonisolated init() {}

    func validate(_ record: RecordItem) throws {
        guard let recordType = record.recordType else {
            throw RecordValidationError.invalidType(record.type)
        }

        try validate(
            type: recordType,
            value: record.value,
            leftNursingSeconds: record.leftNursingSeconds,
            rightNursingSeconds: record.rightNursingSeconds,
            subType: record.subType,
            tags: record.tags,
            note: record.note,
            imageURL: record.imageURL
        )
    }

    func validate(
        type: RecordType,
        value: Double?,
        leftNursingSeconds: Int = 0,
        rightNursingSeconds: Int = 0,
        subType: String?,
        tags: [String]?,
        note: String?,
        imageURL: String?
    ) throws {
        switch type {
        case .milk:
            let bottleAmount = Int((value ?? 0).rounded(.towardZero))
            let totalNursingSeconds = max(leftNursingSeconds, 0) + max(rightNursingSeconds, 0)

            guard bottleAmount >= 0, leftNursingSeconds >= 0, rightNursingSeconds >= 0 else {
                throw RecordValidationError.missingPositiveValue(.milk)
            }

            guard bottleAmount > 0 || totalNursingSeconds > 0 else {
                throw RecordValidationError.missingPositiveValue(.milk)
            }
        case .sleep:
            guard let value, value > 0 else {
                throw RecordValidationError.missingPositiveValue(.sleep)
            }
        case .height:
            guard let value, value > 0 else {
                throw RecordValidationError.missingPositiveValue(.height)
            }
        case .weight:
            guard let value, value > 0 else {
                throw RecordValidationError.missingPositiveValue(.weight)
            }
        case .headCircumference:
            guard let value, (30...60).contains(value) else {
                throw RecordValidationError.missingPositiveValue(.headCircumference)
            }
        case .diaper:
            guard let subtype = subType, DiaperSubtype(rawValue: subtype) != nil else {
                throw RecordValidationError.invalidDiaperSubtype(subType)
            }
        case .food:
            let hasTags = !(tags?.normalizedStrings.isEmpty ?? true)
            let hasNote = !(note?.trimmed.isEmpty ?? true)
            let hasImage = !(imageURL?.trimmed.isEmpty ?? true)

            if !(hasTags || hasNote || hasImage) {
                throw RecordValidationError.emptyFood
            }
        }
    }

    func validateFeeding(leftSeconds: Int, rightSeconds: Int, bottleAmountMl: Int) throws {
        try validate(
            type: .milk,
            value: bottleAmountMl > 0 ? Double(bottleAmountMl) : nil,
            leftNursingSeconds: leftSeconds,
            rightNursingSeconds: rightSeconds,
            subType: nil,
            tags: nil,
            note: nil,
            imageURL: nil
        )
    }

    func validateDiaper(subtype: DiaperSubtype) throws {
        try validate(
            type: .diaper,
            value: nil,
            subType: subtype.rawValue,
            tags: nil,
            note: nil,
            imageURL: nil
        )
    }

    func validateSleep(startedAt: Date, endedAt: Date) throws {
        guard endedAt > startedAt else {
            throw RecordValidationError.invalidSleepRange
        }

        try validate(
            type: .sleep,
            value: endedAt.timeIntervalSince(startedAt),
            subType: nil,
            tags: nil,
            note: nil,
            imageURL: nil
        )
    }

    func validateFood(tags: [String], note: String?, imageURL: String?) throws {
        try validate(
            type: .food,
            value: nil,
            subType: nil,
            tags: tags,
            note: note,
            imageURL: imageURL
        )
    }
}

private extension Array where Element == String {
    var normalizedStrings: [String] {
        map(\.trimmed).filter { !$0.isEmpty }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
