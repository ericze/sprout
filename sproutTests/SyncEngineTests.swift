import Foundation
import SwiftData
import Testing
@testable import sprout

@MainActor
struct SyncEngineTests {
    @Test("push pipeline uploads assets before upserts, uses fixed order, and writes back remote metadata")
    func pushPipelineUploadsBeforeUpserts() async throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let userID = UUID()
        let baby = BabyProfile(
            name: "Sprout",
            birthDate: Date(timeIntervalSince1970: 1_700_000_000),
            avatarPath: try makeTemporaryAsset(named: "avatar")
        )
        let record = RecordItem(
            babyID: baby.id,
            timestamp: Date(timeIntervalSince1970: 1_710_000_100),
            type: RecordType.food.rawValue,
            imageURL: try makeTemporaryAsset(named: "food")
        )
        let memory = MemoryEntry(
            babyID: baby.id,
            createdAt: Date(timeIntervalSince1970: 1_710_000_200),
            ageInDays: 30,
            imageLocalPaths: [
                try makeTemporaryAsset(named: "memory-0"),
                try makeTemporaryAsset(named: "memory-1")
            ],
            note: "first laugh",
            isMilestone: true
        )
        environment.modelContext.insert(baby)
        environment.modelContext.insert(record)
        environment.modelContext.insert(memory)
        try environment.modelContext.save()

        let mock = MockSupabaseService()
        let engine = SyncEngine(
            modelContext: environment.modelContext,
            supabaseService: mock,
            currentUserIDProvider: { userID },
            nowProvider: { environment.now.value }
        )

        #expect(engine.syncUIState.pendingUpsertCount == 3)
        #expect(engine.syncUIState.pendingDeletionCount == 0)

        await engine.performFullSync(reason: .manual)

        let operations = await mock.readOperations()
        let expectedBabyPath = AssetSyncService.avatarStoragePath(userID: userID, babyID: baby.id)
        let expectedRecordPath = AssetSyncService.foodPhotoStoragePath(userID: userID, recordID: record.id)
        let expectedMemoryPaths = AssetSyncService.treasurePhotoStoragePaths(
            userID: userID,
            entryID: memory.id,
            localImageCount: 2
        )

        #expect(
            operations == [
                .uploadAsset(bucket: .babyAvatars, path: expectedBabyPath, contentType: "image/jpeg"),
                .upsertBabyProfile(id: baby.id, expectedVersion: nil, avatarStoragePath: expectedBabyPath),
                .uploadAsset(bucket: .foodPhotos, path: expectedRecordPath, contentType: "image/jpeg"),
                .upsertRecordItem(id: record.id, expectedVersion: nil, imageStoragePath: expectedRecordPath),
                .uploadAsset(bucket: .treasurePhotos, path: expectedMemoryPaths[0], contentType: "image/jpeg"),
                .uploadAsset(bucket: .treasurePhotos, path: expectedMemoryPaths[1], contentType: "image/jpeg"),
                .upsertMemoryEntry(id: memory.id, expectedVersion: nil, imageStoragePaths: expectedMemoryPaths)
            ]
        )

        let fetchedBaby = try fetchBaby(id: baby.id, in: environment.modelContext)
        let fetchedRecord = try fetchRecord(id: record.id, in: environment.modelContext)
        let fetchedMemory = try fetchMemory(id: memory.id, in: environment.modelContext)

        #expect(fetchedBaby?.syncState == .synced)
        #expect(fetchedBaby?.remoteVersion == 1)
        #expect(fetchedBaby?.remoteAvatarPath == expectedBabyPath)
        #expect(fetchedRecord?.syncState == .synced)
        #expect(fetchedRecord?.remoteVersion == 1)
        #expect(fetchedRecord?.remoteImagePath == expectedRecordPath)
        #expect(fetchedMemory?.syncState == .synced)
        #expect(fetchedMemory?.remoteVersion == 1)
        #expect(fetchedMemory?.remoteImagePaths == expectedMemoryPaths)
        #expect(engine.syncUIState.pendingUpsertCount == 0)
        #expect(engine.syncUIState.pendingDeletionCount == 0)
        #expect(engine.syncUIState.lastReason == .manual)
        #expect(engine.syncUIState.phase == .idle)
    }

    @Test("push pipeline soft deletes tombstones in fixed order and clears local tombstones")
    func pushPipelineDeletesInFixedOrder() async throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_100_000))
        let userID = UUID()
        let babyID = UUID()
        let recordID = UUID()
        let memoryID = UUID()
        let deletedAt = environment.now.value

        let babyPath = AssetSyncService.avatarStoragePath(userID: userID, babyID: babyID)
        let recordPath = AssetSyncService.foodPhotoStoragePath(userID: userID, recordID: recordID)
        let memoryPaths = AssetSyncService.treasurePhotoStoragePaths(userID: userID, entryID: memoryID, localImageCount: 2)
        let mock = MockSupabaseService(
            babyProfiles: [
                babyID: BabyProfileDTO(
                    id: babyID,
                    userID: userID,
                    name: "Archived",
                    birthDate: deletedAt,
                    gender: nil,
                    avatarStoragePath: babyPath,
                    isActive: false,
                    hasCompletedOnboarding: true,
                    createdAt: deletedAt,
                    updatedAt: deletedAt,
                    version: 4,
                    deletedAt: nil
                )
            ],
            recordItems: [
                recordID: RecordItemDTO(
                    id: recordID,
                    userID: userID,
                    babyID: babyID,
                    type: RecordType.food.rawValue,
                    timestamp: deletedAt,
                    value: nil,
                    leftNursingSeconds: 0,
                    rightNursingSeconds: 0,
                    subType: nil,
                    imageStoragePath: recordPath,
                    aiSummary: nil,
                    tags: nil,
                    note: nil,
                    createdAt: deletedAt,
                    updatedAt: deletedAt,
                    version: 6,
                    deletedAt: nil
                )
            ],
            memoryEntries: [
                memoryID: MemoryEntryDTO(
                    id: memoryID,
                    userID: userID,
                    babyID: babyID,
                    createdAt: deletedAt,
                    ageInDays: 20,
                    imageStoragePaths: memoryPaths,
                    note: nil,
                    isMilestone: false,
                    updatedAt: deletedAt,
                    version: 8,
                    deletedAt: nil
                )
            ]
        )

        let recordTombstone = SyncDeletionTombstone(
            entityType: .recordItem,
            entityID: recordID,
            remoteVersion: 6,
            readyAfter: deletedAt
        )
        recordTombstone.storagePaths = [recordPath]
        let memoryTombstone = SyncDeletionTombstone(
            entityType: .memoryEntry,
            entityID: memoryID,
            remoteVersion: 8,
            readyAfter: deletedAt
        )
        memoryTombstone.storagePaths = memoryPaths
        let babyTombstone = SyncDeletionTombstone(
            entityType: .babyProfile,
            entityID: babyID,
            remoteVersion: 4,
            readyAfter: deletedAt
        )
        babyTombstone.storagePaths = [babyPath]
        environment.modelContext.insert(recordTombstone)
        environment.modelContext.insert(memoryTombstone)
        environment.modelContext.insert(babyTombstone)
        try environment.modelContext.save()

        let engine = SyncEngine(
            modelContext: environment.modelContext,
            supabaseService: mock,
            currentUserIDProvider: { userID },
            nowProvider: { environment.now.value }
        )

        #expect(engine.syncUIState.pendingDeletionCount == 3)

        await engine.performFullSync(reason: .manual)

        #expect(
            await mock.readOperations() == [
                .softDelete(table: .recordItems, id: recordID, expectedVersion: 6),
                .deleteAsset(bucket: .foodPhotos, path: recordPath),
                .softDelete(table: .memoryEntries, id: memoryID, expectedVersion: 8),
                .deleteAsset(bucket: .treasurePhotos, path: memoryPaths[0]),
                .deleteAsset(bucket: .treasurePhotos, path: memoryPaths[1]),
                .softDelete(table: .babyProfiles, id: babyID, expectedVersion: 4),
                .deleteAsset(bucket: .babyAvatars, path: babyPath)
            ]
        )

        let remainingTombstones = try environment.modelContext.fetch(FetchDescriptor<SyncDeletionTombstone>())
        #expect(remainingTombstones.isEmpty)
        #expect(engine.syncUIState.pendingDeletionCount == 0)
    }

    @Test("scheduleSync uses five second default debounce and coalesces rapid writes")
    func scheduleSyncDebouncesRapidWrites() async throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_200_000))
        let userID = UUID()
        let baby = BabyProfile(name: "Timer", birthDate: environment.now.value)
        environment.modelContext.insert(baby)
        try environment.modelContext.save()

        #expect(SyncEngine.defaultDebounceIntervalNanoseconds == 5_000_000_000)

        let mock = MockSupabaseService()
        let engine = SyncEngine(
            modelContext: environment.modelContext,
            supabaseService: mock,
            currentUserIDProvider: { userID },
            nowProvider: { environment.now.value },
            debounceIntervalNanoseconds: 20_000_000
        )

        engine.scheduleSync(reason: .debouncedWrite)
        engine.scheduleSync(reason: .debouncedWrite)

        let expectedOperations: [MockSupabaseService.Operation] = [
            .upsertBabyProfile(id: baby.id, expectedVersion: nil, avatarStoragePath: nil)
        ]
        var operations: [MockSupabaseService.Operation] = []
        for _ in 0..<50 {
            operations = await mock.readOperations()
            if operations == expectedOperations {
                break
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(operations == expectedOperations)
        #expect(engine.syncUIState.lastReason == .debouncedWrite)
    }

    @Test("version conflicts pull latest remote version and retry exactly once")
    func versionConflictRetriesOnce() async throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_300_000))
        let userID = UUID()
        let babyID = UUID()
        let record = RecordItem(
            id: UUID(),
            babyID: babyID,
            timestamp: environment.now.value,
            type: RecordType.milk.rawValue,
            value: 120,
            remoteVersion: 3,
            syncStateRaw: SyncState.pendingUpsert.rawValue
        )
        environment.modelContext.insert(record)
        try environment.modelContext.save()

        let serverRecord = RecordItemDTO(
            id: record.id,
            userID: userID,
            babyID: babyID,
            type: RecordType.milk.rawValue,
            timestamp: environment.now.value,
            value: 90,
            leftNursingSeconds: 0,
            rightNursingSeconds: 0,
            subType: nil,
            imageStoragePath: nil,
            aiSummary: nil,
            tags: nil,
            note: "remote",
            createdAt: environment.now.value,
            updatedAt: environment.now.value,
            version: 7,
            deletedAt: nil
        )
        let mock = MockSupabaseService(recordItems: [record.id: serverRecord])
        let engine = SyncEngine(
            modelContext: environment.modelContext,
            supabaseService: mock,
            currentUserIDProvider: { userID },
            nowProvider: { environment.now.value }
        )

        await engine.performFullSync(reason: .manual)

        #expect(
            await mock.readOperations() == [
                .upsertRecordItem(id: record.id, expectedVersion: 3, imageStoragePath: nil),
                .upsertRecordItem(id: record.id, expectedVersion: 7, imageStoragePath: nil)
            ]
        )

        let fetchedRecord = try fetchRecord(id: record.id, in: environment.modelContext)
        #expect(fetchedRecord?.remoteVersion == 8)
        #expect(fetchedRecord?.syncState == .synced)
        #expect(engine.syncUIState.phase == .idle)
    }

    @Test("successful earlier rows stay persisted when a later row fails")
    func partialFailurePersistsEarlierSuccess() async throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_350_000))
        let userID = UUID()
        let baby = BabyProfile(name: "Persisted", birthDate: environment.now.value)
        let record = RecordItem(
            babyID: baby.id,
            timestamp: environment.now.value.addingTimeInterval(60),
            type: RecordType.food.rawValue
        )
        environment.modelContext.insert(baby)
        environment.modelContext.insert(record)
        try environment.modelContext.save()

        let mock = MockSupabaseService()
        await mock.stubRecordUpsertError(StubSyncError.boom)
        let engine = SyncEngine(
            modelContext: environment.modelContext,
            supabaseService: mock,
            currentUserIDProvider: { userID },
            nowProvider: { environment.now.value }
        )

        await engine.performFullSync(reason: .manual)

        let reloadedContext = ModelContext(environment.modelContext.container)
        let persistedBaby = try fetchBaby(id: baby.id, in: reloadedContext)
        let persistedRecord = try fetchRecord(id: record.id, in: reloadedContext)

        #expect(persistedBaby?.syncState == .synced)
        #expect(persistedBaby?.remoteVersion == 1)
        #expect(persistedRecord?.syncState == .pendingUpsert)
        #expect(persistedRecord?.remoteVersion == nil)
        #expect(engine.syncUIState.phase == .error("boom"))
    }

    private func fetchBaby(id: UUID, in context: ModelContext) throws -> BabyProfile? {
        var descriptor = FetchDescriptor<BabyProfile>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchRecord(id: UUID, in context: ModelContext) throws -> RecordItem? {
        var descriptor = FetchDescriptor<RecordItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchMemory(id: UUID, in context: ModelContext) throws -> MemoryEntry? {
        var descriptor = FetchDescriptor<MemoryEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func makeTemporaryAsset(named name: String) throws -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-engine-\(name)-\(UUID().uuidString).jpg")
        try Data("asset-\(name)".utf8).write(to: url, options: .atomic)
        return url.path
    }
}

private enum StubSyncError: LocalizedError {
    case boom

    var errorDescription: String? {
        "boom"
    }
}
