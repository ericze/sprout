import Foundation
import os
import SwiftData

nonisolated final class RecordRepository {
    private static let logger = Logger(subsystem: "sprout", category: "RecordRepository")
    private let modelContext: ModelContext
    private let validator: RecordValidator
    private let calendar: Calendar
    private let nowProvider: () -> Date

    @MainActor
    init(
        modelContext: ModelContext,
        validator: RecordValidator = RecordValidator(),
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.validator = validator
        self.calendar = calendar
        self.nowProvider = nowProvider
    }
}

enum RecordRepositoryError: Error, Equatable {
    case recordNotFound(UUID)
    case recordTypeMismatch(expected: RecordType, actual: RecordType)
    case missingFoodPhoto(String)
}

enum RecordDeletionStrategy: Equatable {
    case immediateCleanup
    case recoverable(undoWindow: TimeInterval)

    static let undoable = Self.recoverable(undoWindow: 4)
}

@MainActor
extension RecordRepository {
    /// Creates a feeding record for the provided timestamp and intake values.
    func createFeedingRecord(leftSeconds: Int, rightSeconds: Int, bottleAmountMl: Int, at date: Date) throws -> RecordItem {
        flushExpiredPendingFoodPhotoRemovals()
        try validator.validateFeeding(leftSeconds: leftSeconds, rightSeconds: rightSeconds, bottleAmountMl: bottleAmountMl)
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

    /// Creates a diaper record for the provided timestamp and subtype.
    func createDiaperRecord(subtype: DiaperSubtype, at date: Date) throws -> RecordItem {
        flushExpiredPendingFoodPhotoRemovals()
        try validator.validateDiaper(subtype: subtype)
        let record = RecordItem(
            timestamp: date,
            type: RecordType.diaper.rawValue,
            subType: subtype.rawValue
        )
        try insert(record)
        return record
    }

    /// Creates a sleep record whose duration is derived from the provided start and end dates.
    func createSleepRecord(startedAt: Date, endedAt: Date) throws -> RecordItem {
        flushExpiredPendingFoodPhotoRemovals()
        try validator.validateSleep(startedAt: startedAt, endedAt: endedAt)
        let duration = endedAt.timeIntervalSince(startedAt)
        let record = RecordItem(
            timestamp: startedAt,
            type: RecordType.sleep.rawValue,
            value: duration
        )
        try insert(record)
        return record
    }

    /// Creates a food record after normalizing tags, note and image path.
    func createFoodRecord(tags: [String], note: String?, imageURL: String?, at date: Date) throws -> RecordItem {
        flushExpiredPendingFoodPhotoRemovals()
        let normalizedFood = normalizeFood(tags: tags, note: note, imageURL: imageURL)
        try validator.validateFood(
            tags: normalizedFood.tags ?? [],
            note: normalizedFood.note,
            imageURL: normalizedFood.imageURL
        )
        let record = RecordItem(
            timestamp: date,
            type: RecordType.food.rawValue,
            imageURL: normalizedFood.imageURL,
            tags: normalizedFood.tags,
            note: normalizedFood.note
        )
        try insert(record)
        return record
    }

    /// Updates a feeding record while preserving its identifier.
    func updateFeeding(
        id: UUID,
        at date: Date,
        leftSeconds: Int,
        rightSeconds: Int,
        bottleAmountMl: Int
    ) throws -> RecordItem {
        flushExpiredPendingFoodPhotoRemovals()
        try validator.validateFeeding(leftSeconds: leftSeconds, rightSeconds: rightSeconds, bottleAmountMl: bottleAmountMl)

        let record = try fetchRequiredRecord(id: id, expectedType: .milk)
        record.timestamp = date
        record.value = bottleAmountMl > 0 ? Double(bottleAmountMl) : nil
        record.leftNursingSeconds = leftSeconds
        record.rightNursingSeconds = rightSeconds
        record.subType = nil
        record.imageURL = nil
        record.aiSummary = nil
        record.tags = nil
        record.note = nil

        try persistChanges(for: record)
        return record
    }

    /// Updates a diaper record while preserving its identifier.
    func updateDiaper(id: UUID, subtype: DiaperSubtype, at date: Date) throws -> RecordItem {
        flushExpiredPendingFoodPhotoRemovals()
        try validator.validateDiaper(subtype: subtype)

        let record = try fetchRequiredRecord(id: id, expectedType: .diaper)
        record.timestamp = date
        record.value = nil
        record.leftNursingSeconds = 0
        record.rightNursingSeconds = 0
        record.subType = subtype.rawValue
        record.imageURL = nil
        record.aiSummary = nil
        record.tags = nil
        record.note = nil

        try persistChanges(for: record)
        return record
    }

    /// Updates a sleep record using start and end dates, and recalculates duration automatically.
    func updateSleep(id: UUID, startedAt: Date, endedAt: Date) throws -> RecordItem {
        flushExpiredPendingFoodPhotoRemovals()
        try validator.validateSleep(startedAt: startedAt, endedAt: endedAt)

        let record = try fetchRequiredRecord(id: id, expectedType: .sleep)
        record.timestamp = startedAt
        record.value = endedAt.timeIntervalSince(startedAt)
        record.leftNursingSeconds = 0
        record.rightNursingSeconds = 0
        record.subType = nil
        record.imageURL = nil
        record.aiSummary = nil
        record.tags = nil
        record.note = nil

        try persistChanges(for: record)
        return record
    }

    /// Updates a food record while preserving its identifier and cleaning up replaced images.
    func updateFood(id: UUID, tags: [String], note: String?, imageURL: String?, at date: Date) throws -> RecordItem {
        flushExpiredPendingFoodPhotoRemovals()
        let normalizedFood = normalizeFood(tags: tags, note: note, imageURL: imageURL)
        try validator.validateFood(
            tags: normalizedFood.tags ?? [],
            note: normalizedFood.note,
            imageURL: normalizedFood.imageURL
        )

        let record = try fetchRequiredRecord(id: id, expectedType: .food)
        let previousImagePath = record.imageURL?.trimmed.nilIfEmpty

        record.timestamp = date
        record.value = nil
        record.leftNursingSeconds = 0
        record.rightNursingSeconds = 0
        record.subType = nil
        record.imageURL = normalizedFood.imageURL
        record.aiSummary = nil
        record.tags = normalizedFood.tags
        record.note = normalizedFood.note

        try persistChanges(for: record)

        if previousImagePath != record.imageURL, let previousImagePath, !FoodPhotoStorage.removeImage(at: previousImagePath) {
            Self.logger.error("Food image cleanup failed after update for path: \(previousImagePath, privacy: .public)")
        }

        return record
    }

    func updateFeedingRecord(
        id: UUID,
        leftSeconds: Int,
        rightSeconds: Int,
        bottleAmountMl: Int,
        at date: Date
    ) throws -> RecordItem {
        try updateFeeding(
            id: id,
            at: date,
            leftSeconds: leftSeconds,
            rightSeconds: rightSeconds,
            bottleAmountMl: bottleAmountMl
        )
    }

    func updateDiaperRecord(id: UUID, subtype: DiaperSubtype, at date: Date) throws -> RecordItem {
        try updateDiaper(id: id, subtype: subtype, at: date)
    }

    func updateSleepRecord(id: UUID, startedAt: Date, endedAt: Date) throws -> RecordItem {
        try updateSleep(id: id, startedAt: startedAt, endedAt: endedAt)
    }

    func updateFoodRecord(id: UUID, tags: [String], note: String?, imageURL: String?, at date: Date) throws -> RecordItem {
        try updateFood(id: id, tags: tags, note: note, imageURL: imageURL, at: date)
    }

    func fetchTodayRecords(referenceDate: Date) throws -> [RecordItem] {
        flushExpiredPendingFoodPhotoRemovals()
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
        flushExpiredPendingFoodPhotoRemovals()
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
        flushExpiredPendingFoodPhotoRemovals()
        var descriptor = FetchDescriptor<RecordItem>(
            predicate: #Predicate<RecordItem> { item in
                item.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func fetchRecentFoodTags(limit: Int = 8, sampleRecordLimit: Int = 30) throws -> [String] {
        flushExpiredPendingFoodPhotoRemovals()
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
        flushExpiredPendingFoodPhotoRemovals()
        let descriptor = FetchDescriptor<RecordItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    /// Deletes a record and optionally preserves enough state for a short undo window.
    @discardableResult
    func deleteRecord(
        id: UUID,
        strategy: RecordDeletionStrategy = .immediateCleanup
    ) throws -> RecordRecoverySnapshot? {
        flushExpiredPendingFoodPhotoRemovals()
        guard let record = try fetchRecord(id: id) else { return nil }
        let snapshot = record.recoverySnapshot
        let imagePath = record.imageURL?.trimmed.nilIfEmpty
        removeDeletionTombstones(for: id)
        modelContext.delete(record)
        createDeletionTombstone(for: record, strategy: strategy)
        try modelContext.save()

        switch strategy {
        case .immediateCleanup:
            FoodPhotoStorage.cancelPendingRemoval(for: id, path: imagePath)
            if let imagePath, !FoodPhotoStorage.removeImage(at: imagePath) {
                Self.logger.error("Record deleted but image cleanup failed for path: \(imagePath, privacy: .public)")
            }
        case let .recoverable(undoWindow):
            if let imagePath {
                FoodPhotoStorage.schedulePendingRemoval(
                    for: id,
                    at: imagePath,
                    deleteAfter: nowProvider().addingTimeInterval(max(undoWindow, 0))
                )
            }
        }

        return snapshot
    }

    /// Restores a previously deleted record without changing its identifier.
    func restoreDeletedRecord(from snapshot: RecordRecoverySnapshot) throws -> RecordItem {
        flushExpiredPendingFoodPhotoRemovals()

        if let existingRecord = try fetchRecord(id: snapshot.recordID) {
            if removeDeletionTombstones(for: snapshot.recordID) {
                try modelContext.save()
            }
            return existingRecord
        }

        let restoredImagePath = snapshot.imageURL?.trimmed.nilIfEmpty
        if let restoredImagePath, !FoodPhotoStorage.hasImage(at: restoredImagePath) {
            throw RecordRepositoryError.missingFoodPhoto(restoredImagePath)
        }

        let normalizedFood = normalizeFood(
            tags: snapshot.tags ?? [],
            note: snapshot.note,
            imageURL: restoredImagePath
        )

        let restoredRecord = RecordItem(
            id: snapshot.recordID,
            timestamp: snapshot.timestamp,
            type: snapshot.type.rawValue,
            value: snapshot.type == .food ? nil : snapshot.value,
            leftNursingSeconds: snapshot.type == .milk ? snapshot.leftNursingSeconds : 0,
            rightNursingSeconds: snapshot.type == .milk ? snapshot.rightNursingSeconds : 0,
            subType: snapshot.type == .diaper ? snapshot.subType : nil,
            imageURL: snapshot.type == .food ? normalizedFood.imageURL : nil,
            aiSummary: snapshot.aiSummary,
            tags: snapshot.type == .food ? normalizedFood.tags : nil,
            note: snapshot.type == .food ? normalizedFood.note : nil
        )

        _ = removeDeletionTombstones(for: snapshot.recordID)
        try insert(restoredRecord)
        FoodPhotoStorage.cancelPendingRemoval(for: snapshot.recordID, path: restoredImagePath)
        return restoredRecord
    }

    /// Finalizes a recoverable delete after the undo window has elapsed.
    func finalizeDeletedRecord(_ snapshot: RecordRecoverySnapshot) throws {
        flushExpiredPendingFoodPhotoRemovals()
        let imagePath = snapshot.imageURL?.trimmed.nilIfEmpty
        FoodPhotoStorage.cancelPendingRemoval(for: snapshot.recordID, path: imagePath)

        guard try fetchRecord(id: snapshot.recordID) == nil else {
            return
        }

        if let imagePath, !FoodPhotoStorage.removeImage(at: imagePath) {
            Self.logger.error("Record finalization cleanup failed for path: \(imagePath, privacy: .public)")
        }
    }

    private func insert(_ record: RecordItem) throws {
        applyCreateSyncMetadata(to: record)
        try validator.validate(record)
        modelContext.insert(record)
        try modelContext.save()
    }

    private func persistChanges(for record: RecordItem) throws {
        record.syncState = .pendingUpsert
        try validator.validate(record)
        try modelContext.save()
    }

    private func fetchRequiredRecord(id: UUID, expectedType: RecordType) throws -> RecordItem {
        guard let record = try fetchRecord(id: id) else {
            throw RecordRepositoryError.recordNotFound(id)
        }

        guard let actualType = record.recordType else {
            throw RecordValidationError.invalidType(record.type)
        }

        guard actualType == expectedType else {
            throw RecordRepositoryError.recordTypeMismatch(expected: expectedType, actual: actualType)
        }

        return record
    }

    private func normalizeFood(tags: [String], note: String?, imageURL: String?) -> (tags: [String]?, note: String?, imageURL: String?) {
        let normalizedTags = tags
            .map(\.trimmed)
            .filter { !$0.isEmpty }
        let normalizedNote = note?.trimmed.nilIfEmpty
        let normalizedImageURL = imageURL?.trimmed.nilIfEmpty
        return (
            tags: normalizedTags.isEmpty ? nil : normalizedTags,
            note: normalizedNote,
            imageURL: normalizedImageURL
        )
    }

    private func applyCreateSyncMetadata(to record: RecordItem) {
        if let activeBabyID = resolvedActiveBabyID() {
            record.babyID = activeBabyID
        }
        record.remoteVersion = nil
        record.syncState = .pendingUpsert
    }

    private func resolvedActiveBabyID() -> UUID? {
        var activeDescriptor = FetchDescriptor<BabyProfile>(
            predicate: #Predicate<BabyProfile> { $0.isActive == true }
        )
        activeDescriptor.fetchLimit = 1

        if let activeBaby = try? modelContext.fetch(activeDescriptor).first {
            let activeBabyID = activeBaby.id
            return activeBabyID
        }

        var fallbackDescriptor = FetchDescriptor<BabyProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        fallbackDescriptor.fetchLimit = 1
        let fallbackBaby = try? modelContext.fetch(fallbackDescriptor).first
        return fallbackBaby?.id
    }

    private func createDeletionTombstone(for record: RecordItem, strategy: RecordDeletionStrategy) {
        let readyAfter: Date
        switch strategy {
        case .immediateCleanup:
            readyAfter = nowProvider()
        case let .recoverable(undoWindow):
            readyAfter = nowProvider().addingTimeInterval(max(undoWindow, 0))
        }

        let tombstone = SyncDeletionTombstone(
            entityType: .recordItem,
            entityID: record.id,
            remoteVersion: record.remoteVersion,
            readyAfter: readyAfter
        )
        if let remoteImagePath = record.remoteImagePath?.trimmed.nilIfEmpty {
            tombstone.storagePaths = [remoteImagePath]
        }
        modelContext.insert(tombstone)
    }

    @discardableResult
    private func removeDeletionTombstones(for recordID: UUID) -> Bool {
        let entityTypeRaw = SyncDeletionEntityType.recordItem.rawValue
        let descriptor = FetchDescriptor<SyncDeletionTombstone>(
            predicate: #Predicate<SyncDeletionTombstone> { tombstone in
                tombstone.entityID == recordID && tombstone.entityTypeRaw == entityTypeRaw
            }
        )
        guard let tombstones = try? modelContext.fetch(descriptor), !tombstones.isEmpty else {
            return false
        }
        tombstones.forEach(modelContext.delete)
        return true
    }

    private func flushExpiredPendingFoodPhotoRemovals() {
        FoodPhotoStorage.flushExpiredPendingRemovals(now: nowProvider())
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
