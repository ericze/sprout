import Foundation
import SwiftData
import Testing
@testable import sprout

@MainActor
struct LocalSyncBootstrapperTests {
    @Test("Bootstrap creates a default active baby when the store is empty")
    func createsDefaultBabyWhenNeeded() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let bootstrapper = LocalSyncBootstrapper(modelContext: environment.modelContext)

        let report = bootstrapper.prepareForSync()
        let babies = try fetchBabies(from: environment.modelContext)

        #expect(report.createdDefaultBaby)
        #expect(babies.count == 1)
        #expect(babies.first?.isActive == true)
        #expect(babies.first?.syncStateRaw == SyncState.pendingUpsert.rawValue)
        #expect(babies.first?.remoteVersion == nil)
    }

    @Test("Bootstrap backfills babyID and marks sync rows dirty without mutating weekly letters")
    func backfillsLegacyRowsAndKeepsWeeklyLettersUntouched() throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_710_000_000))
        let modelContext = environment.modelContext
        let firstBabyID = UUID()
        let secondBabyID = UUID()

        let firstBaby = BabyProfile(
            id: firstBabyID,
            name: "First",
            birthDate: environment.now.value.addingTimeInterval(-86_400),
            gender: .female,
            createdAt: environment.now.value.addingTimeInterval(-3_600),
            remoteAvatarPath: "baby-avatars/old.jpg",
            remoteVersion: 3,
            syncStateRaw: SyncState.synced.rawValue,
            isActive: true,
            hasCompletedOnboarding: true
        )
        let secondBaby = BabyProfile(
            id: secondBabyID,
            name: "Second",
            birthDate: environment.now.value,
            gender: .male,
            createdAt: environment.now.value,
            remoteAvatarPath: nil,
            remoteVersion: 5,
            syncStateRaw: SyncState.synced.rawValue,
            isActive: true,
            hasCompletedOnboarding: false
        )

        let record = RecordItem(
            id: UUID(),
            babyID: UUID(),
            timestamp: environment.now.value,
            type: RecordType.milk.rawValue,
            value: 120,
            leftNursingSeconds: 0,
            rightNursingSeconds: 0,
            remoteImagePath: "food-photos/legacy.jpg",
            remoteVersion: 11,
            syncStateRaw: SyncState.synced.rawValue
        )
        let memory = MemoryEntry(
            id: UUID(),
            babyID: UUID(),
            createdAt: environment.now.value,
            ageInDays: 12,
            imageLocalPaths: [],
            remoteImagePathsPayload: "[\"treasure-photos/a.jpg\"]",
            remoteVersion: 7,
            syncStateRaw: SyncState.synced.rawValue,
            note: "Legacy",
            isMilestone: false
        )
        let weeklyLetter = WeeklyLetter(
            weekStart: environment.now.value.addingTimeInterval(-86_400 * 7),
            weekEnd: environment.now.value,
            density: .normal,
            collapsedText: "unchanged-collapsed",
            expandedText: "unchanged-expanded",
            generatedAt: environment.now.value
        )

        modelContext.insert(firstBaby)
        modelContext.insert(secondBaby)
        modelContext.insert(record)
        modelContext.insert(memory)
        modelContext.insert(weeklyLetter)
        try modelContext.save()

        let bootstrapper = LocalSyncBootstrapper(modelContext: modelContext)
        let report = bootstrapper.prepareForSync()

        #expect(report.createdDefaultBaby == false)

        let babies = try fetchBabies(from: modelContext)
        let activeBabies = babies.filter(\.isActive)
        #expect(activeBabies.count == 1)
        #expect(activeBabies.first?.id == firstBabyID)
        #expect(babies.allSatisfy { $0.syncStateRaw == SyncState.pendingUpsert.rawValue })
        #expect(babies.allSatisfy { $0.remoteVersion == nil })

        let fetchedRecord = try modelContext.fetch(FetchDescriptor<RecordItem>()).first
        #expect(fetchedRecord?.babyID == firstBabyID)
        #expect(fetchedRecord?.syncStateRaw == SyncState.pendingUpsert.rawValue)
        #expect(fetchedRecord?.remoteVersion == nil)

        let fetchedMemory = try modelContext.fetch(FetchDescriptor<MemoryEntry>()).first
        #expect(fetchedMemory?.babyID == firstBabyID)
        #expect(fetchedMemory?.syncStateRaw == SyncState.pendingUpsert.rawValue)
        #expect(fetchedMemory?.remoteVersion == nil)

        let fetchedLetter = try modelContext.fetch(FetchDescriptor<WeeklyLetter>()).first
        #expect(fetchedLetter?.collapsedText == "unchanged-collapsed")
        #expect(fetchedLetter?.expandedText == "unchanged-expanded")
    }

    private func fetchBabies(from context: ModelContext) throws -> [BabyProfile] {
        let descriptor = FetchDescriptor<BabyProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
}
