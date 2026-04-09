import Foundation
import OSLog
import SwiftData

struct LocalSyncBootstrapReport: Equatable, Sendable {
    let createdDefaultBaby: Bool
}

@MainActor
struct LocalSyncBootstrapper {
    private static let emptyUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "sprout", category: "LocalSyncBootstrapper")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func prepareForSync(activeBabyState: ActiveBabyState? = nil) -> LocalSyncBootstrapReport {
        let repository = BabyRepository(modelContext: modelContext, activeBabyState: activeBabyState)
        let hadActiveBaby = repository.activeBaby != nil
        _ = repository.createDefaultIfNeeded()

        do {
            try normalizeLegacyRows(activeBabyState: activeBabyState)
        } catch {
            logger.error("prepareForSync failed: \(String(describing: error), privacy: .public)")
        }

        let hasActiveBaby = repository.activeBaby != nil
        return LocalSyncBootstrapReport(createdDefaultBaby: !hadActiveBaby && hasActiveBaby)
    }

    private func normalizeLegacyRows(activeBabyState: ActiveBabyState?) throws {
        let babies = try fetchBabies()
        guard !babies.isEmpty else { return }

        var hasChanges = false
        for baby in babies {
            if baby.id == Self.emptyUUID {
                baby.id = UUID()
                hasChanges = true
            }
        }

        guard let activeBaby = canonicalActiveBaby(from: babies) else { return }
        let activeBabyID = activeBaby.id

        hasChanges = normalizeActiveBabyFlags(in: babies, activeBabyID: activeBabyID) || hasChanges
        hasChanges = markBabiesDirty(babies) || hasChanges
        hasChanges = backfillRecords(activeBabyID: activeBabyID) || hasChanges
        hasChanges = backfillMemoryEntries(activeBabyID: activeBabyID) || hasChanges

        if hasChanges {
            try modelContext.save()
        }

        activeBabyState?.updateFrom(activeBaby)
    }

    private func fetchBabies() throws -> [BabyProfile] {
        let descriptor = FetchDescriptor<BabyProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func canonicalActiveBaby(from babies: [BabyProfile]) -> BabyProfile? {
        if let activeBaby = babies.first(where: \.isActive) {
            return activeBaby
        }
        return babies.first
    }

    private func normalizeActiveBabyFlags(in babies: [BabyProfile], activeBabyID: UUID) -> Bool {
        var hasChanges = false
        for baby in babies {
            let shouldBeActive = baby.id == activeBabyID
            if baby.isActive != shouldBeActive {
                baby.isActive = shouldBeActive
                hasChanges = true
            }
        }
        return hasChanges
    }

    private func markBabiesDirty(_ babies: [BabyProfile]) -> Bool {
        var hasChanges = false
        for baby in babies {
            if baby.remoteVersion != nil {
                baby.remoteVersion = nil
                hasChanges = true
            }
            if baby.syncStateRaw != SyncState.pendingUpsert.rawValue {
                baby.syncStateRaw = SyncState.pendingUpsert.rawValue
                hasChanges = true
            }
        }
        return hasChanges
    }

    private func backfillRecords(activeBabyID: UUID) throws -> Bool {
        let records = try modelContext.fetch(FetchDescriptor<RecordItem>())
        var hasChanges = false

        for record in records {
            if record.babyID != activeBabyID {
                record.babyID = activeBabyID
                hasChanges = true
            }
            if record.remoteVersion != nil {
                record.remoteVersion = nil
                hasChanges = true
            }
            if record.syncStateRaw != SyncState.pendingUpsert.rawValue {
                record.syncStateRaw = SyncState.pendingUpsert.rawValue
                hasChanges = true
            }
        }

        return hasChanges
    }

    private func backfillMemoryEntries(activeBabyID: UUID) throws -> Bool {
        let entries = try modelContext.fetch(FetchDescriptor<MemoryEntry>())
        var hasChanges = false

        for entry in entries {
            if entry.babyID != activeBabyID {
                entry.babyID = activeBabyID
                hasChanges = true
            }
            if entry.remoteVersion != nil {
                entry.remoteVersion = nil
                hasChanges = true
            }
            if entry.syncStateRaw != SyncState.pendingUpsert.rawValue {
                entry.syncStateRaw = SyncState.pendingUpsert.rawValue
                hasChanges = true
            }
        }

        return hasChanges
    }
}
