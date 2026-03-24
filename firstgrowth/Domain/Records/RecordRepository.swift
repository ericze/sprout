import Foundation
import SwiftData

nonisolated final class RecordRepository {
    private let modelContext: ModelContext
    private let validator: RecordValidator
    private let calendar: Calendar

    @MainActor
    init(
        modelContext: ModelContext,
        validator: RecordValidator = RecordValidator(),
        calendar: Calendar = .current
    ) {
        self.modelContext = modelContext
        self.validator = validator
        self.calendar = calendar
    }
}

@MainActor
extension RecordRepository {
    func createFeedingRecord(leftSeconds: Int, rightSeconds: Int, bottleAmountMl: Int, at date: Date) throws -> RecordItem {
        let record = RecordItem(
            timestamp: date,
            type: RecordType.milk.rawValue,
            value: bottleAmountMl > 0 ? Double(bottleAmountMl) : nil,
            leftNursingSeconds: leftSeconds,
            rightNursingSeconds: rightSeconds
        )
        try insert(record)
        return record
    }

    func createDiaperRecord(subtype: DiaperSubtype, at date: Date) throws -> RecordItem {
        let record = RecordItem(
            timestamp: date,
            type: RecordType.diaper.rawValue,
            subType: subtype.rawValue
        )
        try insert(record)
        return record
    }

    func createSleepRecord(startedAt: Date, endedAt: Date) throws -> RecordItem {
        let duration = endedAt.timeIntervalSince(startedAt)
        let record = RecordItem(
            timestamp: startedAt,
            type: RecordType.sleep.rawValue,
            value: duration
        )
        try insert(record)
        return record
    }

    func createFoodRecord(tags: [String], note: String?, imageURL: String?, at date: Date) throws -> RecordItem {
        let normalizedTags = tags.map(\.trimmed).filter { !$0.isEmpty }
        let normalizedNote = note?.trimmed
        let record = RecordItem(
            timestamp: date,
            type: RecordType.food.rawValue,
            imageURL: imageURL?.trimmed.nilIfEmpty,
            tags: normalizedTags.isEmpty ? nil : normalizedTags,
            note: normalizedNote?.nilIfEmpty
        )
        try insert(record)
        return record
    }

    func fetchTodayRecords(referenceDate: Date) throws -> [RecordItem] {
        let startOfDay = calendar.startOfDay(for: referenceDate)
        var descriptor = FetchDescriptor<RecordItem>(
            predicate: #Predicate<RecordItem> { item in
                item.timestamp >= startOfDay && item.timestamp <= referenceDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.includePendingChanges = true
        return try modelContext.fetch(descriptor).filter(\.isHomeRecord)
    }

    func fetchHistory(before date: Date, limit: Int) throws -> [RecordItem] {
        var descriptor = FetchDescriptor<RecordItem>(
            predicate: #Predicate<RecordItem> { item in
                item.timestamp < date
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.includePendingChanges = true
        return try modelContext.fetch(descriptor).filter(\.isHomeRecord)
    }

    func fetchRecord(id: UUID) throws -> RecordItem? {
        var descriptor = FetchDescriptor<RecordItem>(
            predicate: #Predicate<RecordItem> { item in
                item.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func fetchRecentFoodTags(limit: Int = 8, sampleRecordLimit: Int = 30) throws -> [String] {
        var descriptor = FetchDescriptor<RecordItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = sampleRecordLimit

        let records = try modelContext.fetch(descriptor).filter { $0.recordType == .food }
        var suggestions: [String] = []

        for record in records {
            for tag in record.tags ?? [] {
                let normalized = tag.trimmed
                if normalized.isEmpty || suggestions.contains(normalized) {
                    continue
                }
                suggestions.append(normalized)
                if suggestions.count == limit {
                    return suggestions
                }
            }
        }

        return suggestions
    }

    func fetchAllRecords() throws -> [RecordItem] {
        let descriptor = FetchDescriptor<RecordItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    func deleteRecord(id: UUID) throws {
        guard let record = try fetchRecord(id: id) else { return }
        if let path = record.imageURL {
            FoodPhotoStorage.removeImage(at: path)
        }
        modelContext.delete(record)
        try modelContext.save()
    }

    private func insert(_ record: RecordItem) throws {
        try validator.validate(record)
        modelContext.insert(record)
        try modelContext.save()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension RecordItem {
    var isHomeRecord: Bool {
        recordType == .milk || recordType == .diaper || recordType == .sleep || recordType == .food
    }
}
