import Foundation
import SwiftData
import XCTest
@testable import sprout

@MainActor
final class TreasureRepositoryTests: XCTestCase {
    func testCreateMemoryEntryUsesActiveBabyIDAndMarksPendingUpsert() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let activeBabyID = UUID()
        let baby = BabyProfile(
            id: activeBabyID,
            name: "Active",
            birthDate: environment.now.value.addingTimeInterval(-86_400),
            createdAt: environment.now.value.addingTimeInterval(-3_600),
            isActive: true
        )
        environment.modelContext.insert(baby)
        try environment.modelContext.save()

        let entry = try environment.treasureRepository.createMemoryEntry(
            note: "宝宝今天笑了",
            imageLocalPaths: [],
            isMilestone: false,
            createdAt: environment.now.value,
            birthDate: baby.birthDate
        )

        XCTAssertEqual(entry.babyID, activeBabyID)
        XCTAssertEqual(entry.syncStateRaw, SyncState.pendingUpsert.rawValue)
        XCTAssertNil(entry.remoteVersion)
    }

    func testDeleteMemoryEntryCreatesDeletionTombstoneWithRemoteImagePaths() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let activeBaby = BabyProfile(
            id: UUID(),
            name: "Active",
            birthDate: environment.now.value.addingTimeInterval(-86_400),
            createdAt: environment.now.value.addingTimeInterval(-3_600),
            isActive: true
        )
        environment.modelContext.insert(activeBaby)
        try environment.modelContext.save()

        let entry = try environment.treasureRepository.createMemoryEntry(
            note: "远端图片清理",
            imageLocalPaths: [],
            isMilestone: false,
            createdAt: environment.now.value,
            birthDate: activeBaby.birthDate
        )
        entry.remoteVersion = 9
        entry.remoteImagePaths = [
            "treasure-photos/u1/m1/a.jpg",
            "treasure-photos/u1/m1/b.jpg",
        ]
        try environment.modelContext.save()

        try environment.treasureRepository.deleteMemoryEntry(id: entry.id, removeImage: false)

        XCTAssertNil(try environment.treasureRepository.fetchMemoryEntry(id: entry.id))
        var descriptor = FetchDescriptor<SyncDeletionTombstone>(
            predicate: #Predicate<SyncDeletionTombstone> { tombstone in
                tombstone.entityID == entry.id
            }
        )
        descriptor.fetchLimit = 1
        let tombstone = try XCTUnwrap(try environment.modelContext.fetch(descriptor).first)

        XCTAssertEqual(tombstone.entityType, .memoryEntry)
        XCTAssertEqual(tombstone.remoteVersion, 9)
        XCTAssertEqual(
            tombstone.storagePaths,
            ["treasure-photos/u1/m1/a.jpg", "treasure-photos/u1/m1/b.jpg"]
        )
    }

    func testCreateMemoryEntryPersistsAgeInDays() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let birthDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: -10, to: environment.now.value)!

        let entry = try environment.treasureRepository.createMemoryEntry(
            note: "  会抬头了  ",
            imageLocalPaths: [],
            isMilestone: true,
            createdAt: environment.now.value,
            birthDate: birthDate
        )

        XCTAssertEqual(entry.ageInDays, 10)
        XCTAssertEqual(entry.note, "会抬头了")
        XCTAssertTrue(entry.imageLocalPaths.isEmpty)
        XCTAssertEqual(try environment.treasureRepository.fetchMemoryEntries().count, 1)
    }

    func testCreateMemoryEntryTruncatesToMaximumImageCount() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let imagePaths = (0..<8).map { "/tmp/treasure-image-\($0).jpg" }

        let entry = try environment.treasureRepository.createMemoryEntry(
            note: nil,
            imageLocalPaths: imagePaths,
            isMilestone: false,
            createdAt: environment.now.value,
            birthDate: HomeHeaderConfig.placeholder.birthDate
        )

        let expectedPaths = Array(imagePaths.prefix(TreasureLimits.maxImagesPerEntry))
        XCTAssertEqual(entry.imageLocalPaths, expectedPaths)

        let fetchedEntries = try environment.treasureRepository.fetchMemoryEntries()
        XCTAssertEqual(fetchedEntries.first?.imageLocalPaths, expectedPaths)
    }

    func testSyncWeeklyLetterUpsertsAndRemovesAffectedWeek() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let calendar = Calendar(identifier: .gregorian)
        let composer = WeeklyLetterComposer(calendar: calendar)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: environment.now.value))!

        let entry = try environment.treasureRepository.createMemoryEntry(
            note: "这一周留下了第一条。",
            imageLocalPaths: [],
            isMilestone: false,
            createdAt: environment.now.value,
            birthDate: HomeHeaderConfig.placeholder.birthDate
        )

        try environment.treasureRepository.syncWeeklyLetter(
            for: weekStart,
            composer: composer,
            generatedAt: environment.now.value
        )

        var letters = try environment.treasureRepository.fetchWeeklyLetters()
        XCTAssertEqual(letters.count, 1)
        XCTAssertEqual(letters.first?.density, .silent)

        try environment.treasureRepository.deleteMemoryEntry(id: entry.id, removeImage: false)
        try environment.treasureRepository.syncWeeklyLetter(
            for: weekStart,
            composer: composer,
            generatedAt: environment.now.value
        )

        letters = try environment.treasureRepository.fetchWeeklyLetters()
        XCTAssertTrue(letters.isEmpty)
    }

    func testDeleteMemoryEntryRemovesOwnedImageAfterDatabaseDelete() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let imagePath = try TreasurePhotoStorage.storeImageData(Data([0xFF, 0xD8, 0xFF, 0xD9]))

        let entry = try environment.treasureRepository.createMemoryEntry(
            note: "测试删除图片",
            imageLocalPaths: [imagePath],
            isMilestone: false,
            createdAt: environment.now.value,
            birthDate: HomeHeaderConfig.placeholder.birthDate
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: imagePath))

        try environment.treasureRepository.deleteMemoryEntry(id: entry.id, removeImage: true)

        XCTAssertNil(try environment.treasureRepository.fetchMemoryEntry(id: entry.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: imagePath))
    }

    func testDeleteMemoryEntryDoesNotDeleteExternalImagePath() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let externalURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("external-\(UUID().uuidString).jpg")
        try Data([0x01, 0x02, 0x03]).write(to: externalURL)

        defer {
            try? FileManager.default.removeItem(at: externalURL)
        }

        let entry = try environment.treasureRepository.createMemoryEntry(
            note: "外部路径",
            imageLocalPaths: [externalURL.path],
            isMilestone: false,
            createdAt: environment.now.value,
            birthDate: HomeHeaderConfig.placeholder.birthDate
        )

        try environment.treasureRepository.deleteMemoryEntry(id: entry.id, removeImage: true)

        XCTAssertNil(try environment.treasureRepository.fetchMemoryEntry(id: entry.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalURL.path))
    }

    func testDeleteMemoryEntryWithMixedPathsRemovesOnlyOwnedFile() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let ownedPath = try TreasurePhotoStorage.storeImageData(Data([0xAA, 0xBB, 0xCC]))
        let externalURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mixed-external-\(UUID().uuidString).jpg")
        try Data([0x11, 0x22, 0x33]).write(to: externalURL)

        defer {
            try? FileManager.default.removeItem(atPath: ownedPath)
            try? FileManager.default.removeItem(at: externalURL)
        }

        let entry = try environment.treasureRepository.createMemoryEntry(
            note: "混合路径",
            imageLocalPaths: [ownedPath, externalURL.path],
            isMilestone: false,
            createdAt: environment.now.value,
            birthDate: HomeHeaderConfig.placeholder.birthDate
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: ownedPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalURL.path))

        try environment.treasureRepository.deleteMemoryEntry(id: entry.id, removeImage: true)

        XCTAssertNil(try environment.treasureRepository.fetchMemoryEntry(id: entry.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: ownedPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalURL.path))
    }
}
