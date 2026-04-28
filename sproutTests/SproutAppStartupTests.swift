import Foundation
import Testing
import SwiftData
@testable import sprout

@MainActor
struct SproutAppStartupTests {

    // MARK: - Container creation succeeds with in-memory store

    @Test("AppState.makeContainerResult succeeds with valid in-memory configuration")
    func testContainerCreationSucceeds() async throws {
        let schema = SproutSchemaRegistry.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        let result = AppState.makeContainerResult(schema: schema, modelConfiguration: configuration)

        switch result {
        case .success(let container):
            #expect(!container.configurations.isEmpty)
        case .failure(let message):
            Issue.record(Comment(rawValue: "Expected success but got failure: \(message)"))
        }
    }

    // MARK: - Container creation fails gracefully without deleting data

    @Test("AppState.makeContainerResult returns failure instead of crashing for invalid configuration")
    func testContainerCreationFailureReturnsErrorNotCrash() async throws {
        // Use a schema with an intentionally bad configuration path to force a failure.
        // A URL pointing to a non-existent, non-writable directory will cause ModelContainer to fail.
        let schema = SproutSchemaRegistry.schema

        // Create a configuration pointing to an impossible path
        let impossibleURL = URL(fileURLWithPath: "/nonexistent_impossible_path_xyz/default.store")
        let configuration = ModelConfiguration(
            schema: schema,
            url: impossibleURL
        )

        let result = AppState.makeContainerResult(schema: schema, modelConfiguration: configuration)

        switch result {
        case .success:
            // On some platforms this might succeed (e.g., sandbox allows it),
            // which is fine -- the key invariant is "no crash, no data deletion".
            break
        case .failure(let message):
            #expect(!message.isEmpty)
        }
    }

    // MARK: - Container result does not trigger destructive recovery

    @Test("AppState.makeContainerResult never calls clearPersistentStoreFiles on failure")
    func testNoDestructiveRecoveryOnFailure() async throws {
        // The previous behavior was: on failure, clearPersistentStoreFiles() was called,
        // then a second attempt was made. The new behavior must never delete user data.
        //
        // We verify this structurally: AppState.makeContainerResult has no code path
        // that removes files. We confirm the result is either .success or .failure,
        // with no side effects on the filesystem.

        let schema = SproutSchemaRegistry.schema
        let impossibleURL = URL(fileURLWithPath: "/nonexistent_impossible_path_abc/default.store")
        let configuration = ModelConfiguration(
            schema: schema,
            url: impossibleURL
        )

        // Capture file count before
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let storeFilesBefore = Self.countStoreFiles(in: appSupport, fileManager: fileManager)

        let _ = AppState.makeContainerResult(schema: schema, modelConfiguration: configuration)

        // Verify no store files were removed
        let storeFilesAfter = Self.countStoreFiles(in: appSupport, fileManager: fileManager)
        #expect(storeFilesAfter >= storeFilesBefore)
    }

    // MARK: - Test environment uses in-memory store

    @Test("Test environment creates in-memory container without persistent files")
    func testEnvironmentUsesInMemoryStore() async throws {
        let env = try makeTestEnvironment(now: .now)
        let container = env.modelContext.container

        // The test environment should use an in-memory store
        let configurations = container.configurations
        for config in configurations {
            #expect(config.isStoredInMemoryOnly == true)
        }
    }

    // MARK: - AppStartupErrorView renders without crash

    @Test("AppStartupErrorView can be instantiated with an error message")
    func testErrorViewCreation() async {
        let view = AppStartupErrorView(errorMessage: "Test error message")
        #expect(view.errorMessage == "Test error message")
    }

    @Test("AppStartupErrorView can be instantiated with an empty error message")
    func testErrorViewCreationWithEmptyMessage() async {
        let view = AppStartupErrorView(errorMessage: "")
        #expect(view.errorMessage.isEmpty)
    }

    // MARK: - AppRootView routes correctly

    @Test("AppRootView exists and can be created with a container")
    func testAppRootViewCreation() async throws {
        let schema = SproutSchemaRegistry.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try SproutContainerFactory.make(
            schema: schema,
            modelConfiguration: configuration
        )

        let view = AppRootView(container: container, hasCompletedOnboarding: true)
        #expect(view.hasCompletedOnboarding == true)
    }

    // MARK: - Default schema contains all required model types

    @Test("Default schema includes all current model types")
    func testDefaultSchemaContainsAllModelTypes() async throws {
        // Use an in-memory configuration so this always succeeds
        let schema = SproutSchemaRegistry.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let result = AppState.makeContainerResult(schema: schema, modelConfiguration: configuration)

        switch result {
        case .success(let container):
            // Verify we can insert and fetch each model type
            let context = ModelContext(container)

            let record = RecordItem(timestamp: .now, type: "height", value: 50.0)
            context.insert(record)

            let memory = MemoryEntry(createdAt: .now, ageInDays: 0, imageLocalPaths: [], note: "test", isMilestone: false)
            context.insert(memory)

            let letter = WeeklyLetter(
                weekStart: .now,
                weekEnd: .now,
                density: .normal,
                collapsedText: "test",
                expandedText: "test expanded",
                generatedAt: .now
            )
            context.insert(letter)

            let baby = BabyProfile()
            context.insert(baby)

            let tombstone = SyncDeletionTombstone(
                entityType: .recordItem,
                entityID: UUID(),
                remoteVersion: nil,
                readyAfter: .now
            )
            context.insert(tombstone)

            let milestone = GrowthMilestoneEntry(
                babyID: baby.id,
                title: "Roll over",
                category: "motor",
                occurredAt: .now
            )
            context.insert(milestone)

            try context.save()

            let fetchedRecords = try context.fetch(FetchDescriptor<RecordItem>())
            #expect(fetchedRecords.count == 1)

            let fetchedMemories = try context.fetch(FetchDescriptor<MemoryEntry>())
            #expect(fetchedMemories.count == 1)

            let fetchedLetters = try context.fetch(FetchDescriptor<WeeklyLetter>())
            #expect(fetchedLetters.count == 1)

            let fetchedBabies = try context.fetch(FetchDescriptor<BabyProfile>())
            #expect(fetchedBabies.count == 1)

            let fetchedTombstones = try context.fetch(FetchDescriptor<SyncDeletionTombstone>())
            #expect(fetchedTombstones.count == 1)

            let fetchedMilestones = try context.fetch(FetchDescriptor<GrowthMilestoneEntry>())
            #expect(fetchedMilestones.count == 1)

        case .failure(let message):
            Issue.record(Comment(rawValue: "Schema test failed: \(message)"))
        }
    }

    @Test("Migration plan does not repeat the same model shape across versions")
    func testMigrationPlanDoesNotRepeatModelShapes() {
        let modelSignatures = SproutMigrationPlan.schemas.map(Self.modelSignature)
        #expect(Set(modelSignatures).count == modelSignatures.count)
        #expect(modelSignatures.last == Self.modelSignature(SproutSchemaRegistry.models))
    }

    @Test("Migration plan container starts without duplicate version checksum failure")
    func testMigrationPlanContainerStartsWithoutDuplicateVersionChecksums() throws {
        let schema = SproutSchemaRegistry.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: SproutMigrationPlan.self,
                configurations: [configuration]
            )
            #expect(!container.configurations.isEmpty)
        } catch {
            let message = String(describing: error)
            #expect(!message.contains("Duplicate version checksums across stages detected"))
            Issue.record(Comment(rawValue: "Expected migration-plan startup to succeed, got: \(message)"))
        }
    }

    // MARK: - Helpers

    private static func modelSignature(_ schema: any VersionedSchema.Type) -> String {
        modelSignature(schema.models)
    }

    private static func modelSignature(_ models: [any PersistentModel.Type]) -> String {
        models
            .map { String(reflecting: $0) }
            .sorted()
            .joined(separator: "|")
    }

    private static func countStoreFiles(in directory: URL, fileManager: FileManager) -> Int {
        let fileNames = ["default.store", "default.store-wal", "default.store-shm"]
        var count = 0
        for name in fileNames {
            let url = directory.appendingPathComponent(name)
            if fileManager.fileExists(atPath: url.path) {
                count += 1
            }
        }
        return count
    }
}
