import XCTest
import SwiftData
@testable import sprout

@MainActor
final class RecordRepositoryTests: XCTestCase {
    func testCreateRecordAssignsActiveBabyIDAndMarksPendingUpsert() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let babyRepository = environment.makeBabyRepository()
        XCTAssertTrue(babyRepository.createDefaultIfNeeded())
        let activeBaby = try XCTUnwrap(babyRepository.activeBaby)

        let record = try environment.recordRepository.createFeedingRecord(
            leftSeconds: 120,
            rightSeconds: 0,
            bottleAmountMl: 60,
            at: environment.now.value
        )

        XCTAssertEqual(record.babyID, activeBaby.id)
        XCTAssertEqual(record.syncStateRaw, SyncState.pendingUpsert.rawValue)
        XCTAssertNil(record.remoteVersion)
    }

    func testUpdateRecordMarksPendingUpsertAndKeepsRemoteVersion() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let record = try environment.recordRepository.createFeedingRecord(
            leftSeconds: 300,
            rightSeconds: 0,
            bottleAmountMl: 90,
            at: environment.now.value
        )
        record.remoteVersion = 12
        record.syncStateRaw = SyncState.synced.rawValue
        try environment.modelContext.save()

        let updated = try environment.recordRepository.updateFeeding(
            id: record.id,
            at: environment.now.value.addingTimeInterval(600),
            leftSeconds: 360,
            rightSeconds: 120,
            bottleAmountMl: 120
        )

        XCTAssertEqual(updated.syncStateRaw, SyncState.pendingUpsert.rawValue)
        XCTAssertEqual(updated.remoteVersion, 12)
    }

    func testUpdateFeedingPreservesIdentifierAndContent() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let repository = environment.recordRepository
        let original = try repository.createFeedingRecord(leftSeconds: 300, rightSeconds: 0, bottleAmountMl: 60, at: environment.now.value)
        let updatedAt = environment.now.value.addingTimeInterval(900)

        let updated = try repository.updateFeeding(
            id: original.id,
            at: updatedAt,
            leftSeconds: 420,
            rightSeconds: 180,
            bottleAmountMl: 90
        )

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.timestamp, updatedAt)
        XCTAssertEqual(updated.leftNursingSeconds, 420)
        XCTAssertEqual(updated.rightNursingSeconds, 180)
        XCTAssertEqual(updated.bottleAmountMl, 90)
    }

    func testUpdateDiaperPreservesIdentifierAndSubtype() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let repository = environment.recordRepository
        let original = try repository.createDiaperRecord(subtype: .pee, at: environment.now.value)
        let updatedAt = environment.now.value.addingTimeInterval(600)

        let updated = try repository.updateDiaper(id: original.id, subtype: .both, at: updatedAt)

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.timestamp, updatedAt)
        XCTAssertEqual(updated.diaperType, .both)
    }

    func testUpdateSleepRecalculatesDurationFromStartAndEnd() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let repository = environment.recordRepository
        let original = try repository.createSleepRecord(
            startedAt: environment.now.value,
            endedAt: environment.now.value.addingTimeInterval(1_800)
        )
        let updatedStart = environment.now.value.addingTimeInterval(-3_600)
        let updatedEnd = updatedStart.addingTimeInterval(5_400)

        let updated = try repository.updateSleep(id: original.id, startedAt: updatedStart, endedAt: updatedEnd)

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.timestamp, updatedStart)
        XCTAssertEqual(updated.value ?? 0, 5_400, accuracy: 0.001)
        XCTAssertEqual(updated.sleepEndedAt, updatedEnd)
    }

    func testUpdateFoodReplacesPhotoAndCleansPreviousImage() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let repository = environment.recordRepository
        let oldImagePath = try FoodPhotoStorage.storeImageData(Data(repeating: 0x1, count: 32))
        let newImagePath = try FoodPhotoStorage.storeImageData(Data(repeating: 0x2, count: 32))
        defer { FoodPhotoStorage.removeImage(at: oldImagePath) }
        defer { FoodPhotoStorage.removeImage(at: newImagePath) }

        let original = try repository.createFoodRecord(
            tags: ["苹果泥"],
            note: "原始备注",
            imageURL: oldImagePath,
            at: environment.now.value
        )

        let updated = try repository.updateFood(
            id: original.id,
            tags: [" 苹果泥 ", " 南瓜 "],
            note: "  吃得不错  ",
            imageURL: newImagePath,
            at: environment.now.value.addingTimeInterval(300)
        )

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.tags ?? [], ["苹果泥", "南瓜"])
        XCTAssertEqual(updated.note, "吃得不错")
        XCTAssertEqual(updated.imageURL, newImagePath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldImagePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newImagePath))
    }

    func testUpdateFoodRejectsEmptyPayloadAndLeavesExistingRecordUntouched() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let repository = environment.recordRepository
        let original = try repository.createFoodRecord(
            tags: ["南瓜"],
            note: "原始备注",
            imageURL: nil,
            at: environment.now.value
        )

        XCTAssertThrowsError(
            try repository.updateFood(
                id: original.id,
                tags: ["   "],
                note: "   ",
                imageURL: nil,
                at: environment.now.value.addingTimeInterval(60)
            )
        ) { error in
            XCTAssertEqual(error as? RecordValidationError, .emptyFood)
        }

        let fetched = try XCTUnwrap(repository.fetchRecord(id: original.id))
        XCTAssertEqual(fetched.timestamp, original.timestamp)
        XCTAssertEqual(fetched.tags ?? [], ["南瓜"])
        XCTAssertEqual(fetched.note, "原始备注")
    }

    func testRecoverableDeleteAndRestoreKeepsIdentifierAndOrdering() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let repository = environment.recordRepository
        let older = try repository.createFeedingRecord(
            leftSeconds: 0,
            rightSeconds: 0,
            bottleAmountMl: 120,
            at: environment.now.value.addingTimeInterval(-600)
        )
        let newer = try repository.createDiaperRecord(subtype: .pee, at: environment.now.value)

        let snapshot = try XCTUnwrap(repository.deleteRecord(id: older.id, strategy: .undoable))
        let restored = try repository.restoreDeletedRecord(from: snapshot)
        let allRecords = try repository.fetchAllRecords()

        XCTAssertEqual(restored.id, older.id)
        XCTAssertEqual(allRecords.map(\.id), [newer.id, older.id])
    }

    func testDeleteRecordCreatesTombstoneWithExpectedReadyAfterAndRemoteCleanupPath() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let repository = environment.recordRepository
        let record = try repository.createFoodRecord(
            tags: ["香蕉泥"],
            note: nil,
            imageURL: nil,
            at: environment.now.value
        )
        record.remoteVersion = 9
        record.remoteImagePath = "food-photos/user-\(record.id.uuidString)/\(record.id.uuidString).jpg"
        try environment.modelContext.save()

        _ = try repository.deleteRecord(
            id: record.id,
            strategy: .recoverable(undoWindow: 4)
        )

        let tombstones = try fetchRecordTombstones(from: environment.modelContext)
        XCTAssertEqual(tombstones.count, 1)
        XCTAssertEqual(tombstones[0].entityID, record.id)
        XCTAssertEqual(tombstones[0].remoteVersion, 9)
        XCTAssertEqual(
            tombstones[0].readyAfter.timeIntervalSinceReferenceDate,
            environment.now.value.addingTimeInterval(4).timeIntervalSinceReferenceDate,
            accuracy: 0.001
        )
        XCTAssertEqual(tombstones[0].storagePaths, [record.remoteImagePath!])
    }

    func testRestoreDeletedRecordRemovesMatchingTombstone() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let repository = environment.recordRepository
        let record = try repository.createFeedingRecord(
            leftSeconds: 120,
            rightSeconds: 60,
            bottleAmountMl: 40,
            at: environment.now.value
        )

        let snapshot = try XCTUnwrap(repository.deleteRecord(id: record.id, strategy: .undoable))
        XCTAssertEqual(try fetchRecordTombstones(from: environment.modelContext).count, 1)

        _ = try repository.restoreDeletedRecord(from: snapshot)

        XCTAssertEqual(try fetchRecordTombstones(from: environment.modelContext).count, 0)
    }

    func testRecoverableFoodDeleteFinalizationRemovesImageAfterUndoWindow() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let repository = environment.recordRepository
        let imagePath = try FoodPhotoStorage.storeImageData(Data(repeating: 0x3, count: 32))
        defer { FoodPhotoStorage.removeImage(at: imagePath) }

        let record = try repository.createFoodRecord(
            tags: ["鳕鱼"],
            note: nil,
            imageURL: imagePath,
            at: environment.now.value
        )

        let snapshot = try XCTUnwrap(repository.deleteRecord(id: record.id, strategy: .undoable))
        XCTAssertTrue(FileManager.default.fileExists(atPath: imagePath))

        try repository.finalizeDeletedRecord(snapshot)

        XCTAssertFalse(FileManager.default.fileExists(atPath: imagePath))
    }

    func testRestoreDeletedFoodCancelsPendingCleanupAndIsIdempotent() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let repository = environment.recordRepository
        let imagePath = try FoodPhotoStorage.storeImageData(Data(repeating: 0x4, count: 32))
        defer { FoodPhotoStorage.removeImage(at: imagePath) }

        let record = try repository.createFoodRecord(
            tags: ["蓝莓泥"],
            note: "吃了一点点",
            imageURL: imagePath,
            at: environment.now.value
        )

        let snapshot = try XCTUnwrap(repository.deleteRecord(id: record.id, strategy: .undoable))
        let restored = try repository.restoreDeletedRecord(from: snapshot)
        let restoredAgain = try repository.restoreDeletedRecord(from: snapshot)

        environment.now.value = environment.now.value.addingTimeInterval(10)
        let allRecords = try repository.fetchAllRecords()

        XCTAssertEqual(restored.id, record.id)
        XCTAssertEqual(restoredAgain.id, record.id)
        XCTAssertEqual(allRecords.count, 1)
        XCTAssertEqual(allRecords.first?.id, record.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imagePath))
    }

    func testExpiredRecoverableDeleteCleansImageOnNextRepositoryAccess() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let repository = environment.recordRepository
        let imagePath = try FoodPhotoStorage.storeImageData(Data(repeating: 0x5, count: 32))
        defer { FoodPhotoStorage.removeImage(at: imagePath) }

        let record = try repository.createFoodRecord(
            tags: ["南瓜"],
            note: nil,
            imageURL: imagePath,
            at: environment.now.value
        )

        let snapshot = try XCTUnwrap(
            repository.deleteRecord(
                id: record.id,
                strategy: .recoverable(undoWindow: 1)
            )
        )

        environment.now.value = environment.now.value.addingTimeInterval(2)
        _ = try repository.fetchAllRecords()

        XCTAssertFalse(FileManager.default.fileExists(atPath: imagePath))
        XCTAssertThrowsError(try repository.restoreDeletedRecord(from: snapshot)) { error in
            XCTAssertEqual(error as? RecordRepositoryError, .missingFoodPhoto(imagePath))
        }
    }

    private func fetchRecordTombstones(from modelContext: ModelContext) throws -> [SyncDeletionTombstone] {
        let entityTypeRaw = SyncDeletionEntityType.recordItem.rawValue
        let descriptor = FetchDescriptor<SyncDeletionTombstone>(
            predicate: #Predicate<SyncDeletionTombstone> { tombstone in
                tombstone.entityTypeRaw == entityTypeRaw
            }
        )
        return try modelContext.fetch(descriptor)
    }
}
