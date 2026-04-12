import Foundation
import Observation
import SwiftData

enum SyncEngineError: LocalizedError, Equatable {
    case unauthenticated
    case versionConflict(table: SupabaseTable, id: UUID)
    case conflictResolutionFailed(table: SupabaseTable, id: UUID)

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "Cloud sync requires an authenticated user."
        case let .versionConflict(table, id):
            return "Version conflict for \(table.rawValue) row \(id.uuidString)."
        case let .conflictResolutionFailed(table, id):
            return "Failed resolving version conflict for \(table.rawValue) row \(id.uuidString)."
        }
    }
}

enum SyncUIPhase: Equatable, Sendable {
    case idle
    case scheduled
    case pushing
    case error(String)
}

struct SyncUIState: Equatable, Sendable {
    var phase: SyncUIPhase = .idle
    var pendingUpsertCount: Int = 0
    var pendingDeletionCount: Int = 0
    var lastReason: SyncReason?
    var lastCompletedAt: Date?
}

@MainActor
@Observable
final class SyncEngine {
    nonisolated static let defaultDebounceIntervalNanoseconds: UInt64 = 5_000_000_000

    private let modelContext: ModelContext
    private let supabaseService: any SupabaseServicing
    private let currentUserIDProvider: @MainActor () -> UUID?
    private let nowProvider: @MainActor () -> Date
    private let debounceIntervalNanoseconds: UInt64
    @ObservationIgnored private let assetSyncServiceFactory: @MainActor () -> AssetSyncService
    @ObservationIgnored private var syncDebounceTask: Task<Void, Never>?

    var syncUIState: SyncUIState

    init(
        modelContext: ModelContext,
        supabaseService: any SupabaseServicing,
        currentUserIDProvider: @escaping @MainActor () -> UUID?,
        nowProvider: @escaping @MainActor () -> Date = { .now },
        debounceIntervalNanoseconds: UInt64 = SyncEngine.defaultDebounceIntervalNanoseconds,
        assetSyncServiceFactory: @escaping @MainActor () -> AssetSyncService? = { nil }
    ) {
        self.modelContext = modelContext
        self.supabaseService = supabaseService
        self.currentUserIDProvider = currentUserIDProvider
        self.nowProvider = nowProvider
        self.debounceIntervalNanoseconds = debounceIntervalNanoseconds
        self.assetSyncServiceFactory = {
            assetSyncServiceFactory() ?? AssetSyncService(supabaseService: supabaseService)
        }
        syncUIState = SyncUIState()
        refreshPendingCounts()
    }

    func scheduleSync(reason: SyncReason) {
        syncDebounceTask?.cancel()
        syncUIState.lastReason = reason
        syncUIState.phase = .scheduled
        syncDebounceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.debounceIntervalNanoseconds)
            guard !Task.isCancelled else { return }
            self.syncDebounceTask = nil
            await self.performFullSync(reason: reason)
        }
    }

    func performFullSync(reason: SyncReason) async {
        syncDebounceTask?.cancel()
        syncDebounceTask = nil
        syncUIState.lastReason = reason
        syncUIState.phase = .pushing

        do {
            try await pushPendingChanges()
            syncUIState.phase = .idle
            syncUIState.lastCompletedAt = nowProvider()
        } catch {
            syncUIState.phase = .error(error.localizedDescription)
        }

        refreshPendingCounts()
    }

    private func pushPendingChanges() async throws {
        guard let userID = currentUserIDProvider() else {
            throw SyncEngineError.unauthenticated
        }

        let assetSyncService = assetSyncServiceFactory()

        let babies = try fetchPendingBabies()
        for baby in babies {
            try await pushBabyProfile(baby, userID: userID, assetSyncService: assetSyncService)
            try persistModelChangesIfNeeded()
        }

        let records = try fetchPendingRecordItems()
        for record in records {
            try await pushRecordItem(record, userID: userID, assetSyncService: assetSyncService)
            try persistModelChangesIfNeeded()
        }

        let memories = try fetchPendingMemoryEntries()
        for memory in memories {
            try await pushMemoryEntry(memory, userID: userID, assetSyncService: assetSyncService)
            try persistModelChangesIfNeeded()
        }

        let tombstones = try fetchReadyDeletionTombstones()
        for tombstone in tombstones {
            try await pushDeletion(tombstone, assetSyncService: assetSyncService)
            try persistModelChangesIfNeeded()
        }
    }

    private func pushBabyProfile(
        _ baby: BabyProfile,
        userID: UUID,
        assetSyncService: AssetSyncService
    ) async throws {
        let avatarStoragePath = try await assetSyncService.uploadAvatarIfNeeded(userID: userID, baby: baby)
        let dto = makeBabyProfileDTO(baby: baby, userID: userID, avatarStoragePath: avatarStoragePath)
        let saved = try await upsertBabyProfile(dto, localModel: baby)
        baby.remoteVersion = saved.version
        baby.remoteAvatarPath = saved.avatarStoragePath
        baby.syncState = .synced
    }

    private func pushRecordItem(
        _ record: RecordItem,
        userID: UUID,
        assetSyncService: AssetSyncService
    ) async throws {
        let imageStoragePath = try await assetSyncService.uploadFoodPhotoIfNeeded(userID: userID, record: record)
        let dto = makeRecordItemDTO(record: record, userID: userID, imageStoragePath: imageStoragePath)
        let saved = try await upsertRecordItem(dto, localModel: record)
        record.remoteVersion = saved.version
        record.remoteImagePath = saved.imageStoragePath
        record.syncState = .synced
    }

    private func pushMemoryEntry(
        _ entry: MemoryEntry,
        userID: UUID,
        assetSyncService: AssetSyncService
    ) async throws {
        let imageStoragePaths = try await assetSyncService.uploadTreasurePhotosIfNeeded(userID: userID, entry: entry)
        let dto = makeMemoryEntryDTO(entry: entry, userID: userID, imageStoragePaths: imageStoragePaths)
        let saved = try await upsertMemoryEntry(dto, localModel: entry)
        entry.remoteVersion = saved.version
        entry.remoteImagePaths = saved.imageStoragePaths
        entry.syncState = .synced
    }

    private func pushDeletion(
        _ tombstone: SyncDeletionTombstone,
        assetSyncService: AssetSyncService
    ) async throws {
        switch tombstone.entityType {
        case .recordItem:
            try await deleteRemoteRow(
                table: .recordItems,
                id: tombstone.entityID,
                expectedVersion: tombstone.remoteVersion
            )
            try await assetSyncService.deleteAssets(paths: tombstone.storagePaths, bucket: .foodPhotos)
        case .memoryEntry:
            try await deleteRemoteRow(
                table: .memoryEntries,
                id: tombstone.entityID,
                expectedVersion: tombstone.remoteVersion
            )
            try await assetSyncService.deleteAssets(paths: tombstone.storagePaths, bucket: .treasurePhotos)
        case .babyProfile:
            try await deleteRemoteRow(
                table: .babyProfiles,
                id: tombstone.entityID,
                expectedVersion: tombstone.remoteVersion
            )
            try await assetSyncService.deleteAssets(paths: tombstone.storagePaths, bucket: .babyAvatars)
        }

        modelContext.delete(tombstone)
    }

    private func upsertBabyProfile(
        _ dto: BabyProfileDTO,
        localModel: BabyProfile
    ) async throws -> BabyProfileDTO {
        do {
            return try await supabaseService.upsertBabyProfile(dto, expectedVersion: localModel.remoteVersion)
        } catch let error as SyncEngineError {
            guard case .versionConflict = error else { throw error }
            guard let remote = try await fetchRemoteBabyProfile(id: localModel.id) else {
                throw SyncEngineError.conflictResolutionFailed(table: .babyProfiles, id: localModel.id)
            }
            localModel.remoteVersion = remote.version
            localModel.remoteAvatarPath = remote.avatarStoragePath
            let refreshedDTO = makeBabyProfileDTO(
                baby: localModel,
                userID: dto.userID,
                avatarStoragePath: dto.avatarStoragePath
            )
            return try await supabaseService.upsertBabyProfile(refreshedDTO, expectedVersion: remote.version)
        }
    }

    private func upsertRecordItem(
        _ dto: RecordItemDTO,
        localModel: RecordItem
    ) async throws -> RecordItemDTO {
        do {
            return try await supabaseService.upsertRecordItem(dto, expectedVersion: localModel.remoteVersion)
        } catch let error as SyncEngineError {
            guard case .versionConflict = error else { throw error }
            guard let remote = try await fetchRemoteRecordItem(id: localModel.id) else {
                throw SyncEngineError.conflictResolutionFailed(table: .recordItems, id: localModel.id)
            }
            localModel.remoteVersion = remote.version
            localModel.remoteImagePath = remote.imageStoragePath
            let refreshedDTO = makeRecordItemDTO(
                record: localModel,
                userID: dto.userID,
                imageStoragePath: dto.imageStoragePath
            )
            return try await supabaseService.upsertRecordItem(refreshedDTO, expectedVersion: remote.version)
        }
    }

    private func upsertMemoryEntry(
        _ dto: MemoryEntryDTO,
        localModel: MemoryEntry
    ) async throws -> MemoryEntryDTO {
        do {
            return try await supabaseService.upsertMemoryEntry(dto, expectedVersion: localModel.remoteVersion)
        } catch let error as SyncEngineError {
            guard case .versionConflict = error else { throw error }
            guard let remote = try await fetchRemoteMemoryEntry(id: localModel.id) else {
                throw SyncEngineError.conflictResolutionFailed(table: .memoryEntries, id: localModel.id)
            }
            localModel.remoteVersion = remote.version
            localModel.remoteImagePaths = remote.imageStoragePaths
            let refreshedDTO = makeMemoryEntryDTO(
                entry: localModel,
                userID: dto.userID,
                imageStoragePaths: dto.imageStoragePaths
            )
            return try await supabaseService.upsertMemoryEntry(refreshedDTO, expectedVersion: remote.version)
        }
    }

    private func deleteRemoteRow(table: SupabaseTable, id: UUID, expectedVersion: Int64?) async throws {
        do {
            try await supabaseService.softDelete(table: table, id: id, expectedVersion: expectedVersion)
        } catch let error as SyncEngineError {
            guard case .versionConflict = error else { throw error }
            let refreshedVersion = try await fetchRemoteVersion(table: table, id: id)
            try await supabaseService.softDelete(table: table, id: id, expectedVersion: refreshedVersion)
        }
    }

    private func fetchRemoteVersion(table: SupabaseTable, id: UUID) async throws -> Int64? {
        switch table {
        case .babyProfiles:
            return try await fetchRemoteBabyProfile(id: id)?.version
        case .recordItems:
            return try await fetchRemoteRecordItem(id: id)?.version
        case .memoryEntries:
            return try await fetchRemoteMemoryEntry(id: id)?.version
        case .profiles:
            return nil
        }
    }

    private func fetchRemoteBabyProfile(id: UUID) async throws -> BabyProfileDTO? {
        let upperBound = try await supabaseService.fetchServerNow()
        let rows = try await supabaseService.fetchBabyProfiles(updatedAfter: nil, upTo: upperBound)
        return rows.first(where: { $0.id == id })
    }

    private func fetchRemoteRecordItem(id: UUID) async throws -> RecordItemDTO? {
        let upperBound = try await supabaseService.fetchServerNow()
        let rows = try await supabaseService.fetchRecordItems(updatedAfter: nil, upTo: upperBound)
        return rows.first(where: { $0.id == id })
    }

    private func fetchRemoteMemoryEntry(id: UUID) async throws -> MemoryEntryDTO? {
        let upperBound = try await supabaseService.fetchServerNow()
        let rows = try await supabaseService.fetchMemoryEntries(updatedAfter: nil, upTo: upperBound)
        return rows.first(where: { $0.id == id })
    }

    private func refreshPendingCounts() {
        let pendingBabies = (try? fetchPendingBabies().count) ?? 0
        let pendingRecords = (try? fetchPendingRecordItems().count) ?? 0
        let pendingMemories = (try? fetchPendingMemoryEntries().count) ?? 0
        syncUIState.pendingUpsertCount = pendingBabies + pendingRecords + pendingMemories
        syncUIState.pendingDeletionCount = (try? fetchDeletionTombstones().count) ?? 0
    }

    private func persistModelChangesIfNeeded() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }

    private func fetchPendingBabies() throws -> [BabyProfile] {
        let pendingUpsertRawValue = SyncState.pendingUpsert.rawValue
        let descriptor = FetchDescriptor<BabyProfile>(
            predicate: #Predicate<BabyProfile> { $0.syncStateRaw == pendingUpsertRawValue }
        )
        return try modelContext.fetch(descriptor).sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func fetchPendingRecordItems() throws -> [RecordItem] {
        let pendingUpsertRawValue = SyncState.pendingUpsert.rawValue
        let descriptor = FetchDescriptor<RecordItem>(
            predicate: #Predicate<RecordItem> { $0.syncStateRaw == pendingUpsertRawValue }
        )
        return try modelContext.fetch(descriptor).sorted {
            if $0.timestamp != $1.timestamp {
                return $0.timestamp < $1.timestamp
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func fetchPendingMemoryEntries() throws -> [MemoryEntry] {
        let pendingUpsertRawValue = SyncState.pendingUpsert.rawValue
        let descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate<MemoryEntry> { $0.syncStateRaw == pendingUpsertRawValue }
        )
        return try modelContext.fetch(descriptor).sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func fetchDeletionTombstones() throws -> [SyncDeletionTombstone] {
        let descriptor = FetchDescriptor<SyncDeletionTombstone>()
        return try modelContext.fetch(descriptor).sorted {
            if $0.entityTypeRaw != $1.entityTypeRaw {
                return $0.entityTypeRaw < $1.entityTypeRaw
            }
            return $0.entityID.uuidString < $1.entityID.uuidString
        }
    }

    private func fetchReadyDeletionTombstones() throws -> [SyncDeletionTombstone] {
        let allTombstones = try fetchDeletionTombstones()
        let readyDate = nowProvider()
        let deletionOrder: [SyncDeletionEntityType: Int] = [
            .recordItem: 0,
            .memoryEntry: 1,
            .babyProfile: 2
        ]

        return allTombstones
            .filter { $0.readyAfter <= readyDate }
            .sorted { lhs, rhs in
                let lhsOrder = deletionOrder[lhs.entityType] ?? .max
                let rhsOrder = deletionOrder[rhs.entityType] ?? .max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                if lhs.readyAfter != rhs.readyAfter {
                    return lhs.readyAfter < rhs.readyAfter
                }
                return lhs.entityID.uuidString < rhs.entityID.uuidString
            }
    }

    private func makeBabyProfileDTO(
        baby: BabyProfile,
        userID: UUID,
        avatarStoragePath: String?
    ) -> BabyProfileDTO {
        BabyProfileDTO(
            id: baby.id,
            userID: userID,
            name: baby.name,
            birthDate: baby.birthDate,
            gender: baby.gender?.rawValue,
            avatarStoragePath: avatarStoragePath?.trimmed.nilIfEmpty,
            isActive: baby.isActive,
            hasCompletedOnboarding: baby.hasCompletedOnboarding,
            createdAt: baby.createdAt,
            updatedAt: nowProvider(),
            version: baby.remoteVersion ?? 0,
            deletedAt: nil
        )
    }

    private func makeRecordItemDTO(
        record: RecordItem,
        userID: UUID,
        imageStoragePath: String?
    ) -> RecordItemDTO {
        RecordItemDTO(
            id: record.id,
            userID: userID,
            babyID: record.babyID,
            type: record.type,
            timestamp: record.timestamp,
            value: record.value,
            leftNursingSeconds: record.leftNursingSeconds,
            rightNursingSeconds: record.rightNursingSeconds,
            subType: record.subType?.trimmed.nilIfEmpty,
            imageStoragePath: imageStoragePath?.trimmed.nilIfEmpty,
            aiSummary: record.aiSummary?.trimmed.nilIfEmpty,
            tags: record.tags?.map(\.trimmed).filter { !$0.isEmpty }.nilIfEmpty,
            note: record.note?.trimmed.nilIfEmpty,
            createdAt: record.timestamp,
            updatedAt: nowProvider(),
            version: record.remoteVersion ?? 0,
            deletedAt: nil
        )
    }

    private func makeMemoryEntryDTO(
        entry: MemoryEntry,
        userID: UUID,
        imageStoragePaths: [String]
    ) -> MemoryEntryDTO {
        MemoryEntryDTO(
            id: entry.id,
            userID: userID,
            babyID: entry.babyID,
            createdAt: entry.createdAt,
            ageInDays: entry.ageInDays,
            imageStoragePaths: imageStoragePaths.map(\.trimmed).filter { !$0.isEmpty },
            note: entry.note?.trimmed.nilIfEmpty,
            isMilestone: entry.isMilestone,
            updatedAt: nowProvider(),
            version: entry.remoteVersion ?? 0,
            deletedAt: nil
        )
    }
}

private extension Array where Element == String {
    var nilIfEmpty: [String]? {
        isEmpty ? nil : self
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
