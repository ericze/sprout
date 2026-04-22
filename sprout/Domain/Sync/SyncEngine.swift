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
    let cursorStore: SyncCursorStore
    @ObservationIgnored private let assetSyncServiceFactory: @MainActor () -> AssetSyncService
    @ObservationIgnored private var syncDebounceTask: Task<Void, Never>?
    /// Called with the week-start date for each memory entry that was inserted,
    /// updated, or deleted during a pull. The caller should recompute the weekly
    /// letter for that week via `TreasureRepository.syncWeeklyLetter`.
    @ObservationIgnored private let onMemoryPulled: (@MainActor (Date) -> Void)?

    var syncUIState: SyncUIState

    init(
        modelContext: ModelContext,
        supabaseService: any SupabaseServicing,
        currentUserIDProvider: @escaping @MainActor () -> UUID?,
        nowProvider: @escaping @MainActor () -> Date = { .now },
        debounceIntervalNanoseconds: UInt64 = SyncEngine.defaultDebounceIntervalNanoseconds,
        cursorStore: SyncCursorStore = SyncCursorStore(),
        assetSyncServiceFactory: @escaping @MainActor () -> AssetSyncService? = { nil },
        onMemoryPulled: (@MainActor (Date) -> Void)? = nil
    ) {
        self.modelContext = modelContext
        self.supabaseService = supabaseService
        self.currentUserIDProvider = currentUserIDProvider
        self.nowProvider = nowProvider
        self.debounceIntervalNanoseconds = debounceIntervalNanoseconds
        self.cursorStore = cursorStore
        self.assetSyncServiceFactory = {
            assetSyncServiceFactory() ?? AssetSyncService(supabaseService: supabaseService)
        }
        self.onMemoryPulled = onMemoryPulled
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
            try await pullLatestChanges()
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

    // MARK: - Pull

    private func pullLatestChanges() async throws {
        guard let userID = currentUserIDProvider() else {
            throw SyncEngineError.unauthenticated
        }

        // Step 1: Upper-bound snapshot from server.
        let upperBound = try await supabaseService.fetchServerNow()

        // Step 2: Load current cursor for this user.
        var cursor = cursorStore.load(for: userID)

        // Step 3: Fetch per-table in fixed order.
        let remoteBabies = try await supabaseService.fetchBabyProfiles(
            updatedAfter: cursor.babyProfilesAt,
            upTo: upperBound
        )
        let remoteRecords = try await supabaseService.fetchRecordItems(
            updatedAfter: cursor.recordItemsAt,
            upTo: upperBound
        )
        let remoteMemories = try await supabaseService.fetchMemoryEntries(
            updatedAfter: cursor.memoryEntriesAt,
            upTo: upperBound
        )

        // Step 4: Apply all rows (synchronous metadata write).
        var appliedBabies: [BabyProfile] = []
        for remote in remoteBabies {
            if let applied = try apply(remote) {
                appliedBabies.append(applied)
            }
        }
        var appliedRecords: [RecordItem] = []
        for remote in remoteRecords {
            if let applied = try apply(remote) {
                appliedRecords.append(applied)
            }
        }

        // Collect week starts from memory entries that changed during apply.
        var affectedWeekStarts = Set<Date>()
        let pullCalendar = Calendar(identifier: .gregorian)
        var appliedMemories: [MemoryEntry] = []

        for remote in remoteMemories {
            let (wasInsertedOrDeleted, applied) = try apply(remote)
            if let applied {
                appliedMemories.append(applied)
            }
            if wasInsertedOrDeleted, let callback = onMemoryPulled {
                let weekStart = pullCalendar.date(
                    from: pullCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: remote.createdAt)
                ) ?? pullCalendar.startOfDay(for: remote.createdAt)
                affectedWeekStarts.insert(weekStart)
            }
        }

        // Step 4b: Download missing assets (async, after metadata apply).
        let assetSyncService = assetSyncServiceFactory()
        for baby in appliedBabies {
            let localPath = try? await assetSyncService.downloadAvatarIfNeeded(
                userID: userID,
                baby: baby,
                localWritePath: baby.avatarPath
            )
            if let localPath {
                baby.avatarPath = localPath
            }
        }
        for record in appliedRecords {
            let localPath = try? await assetSyncService.downloadFoodPhotoIfNeeded(
                userID: userID,
                record: record,
                localWritePath: record.imageURL
            )
            if let localPath {
                record.imageURL = localPath
            }
        }
        for memory in appliedMemories {
            let localPaths = (try? await assetSyncService.downloadTreasurePhotosIfNeeded(
                userID: userID,
                entry: memory,
                localWritePaths: memory.imageLocalPaths
            )) ?? memory.imageLocalPaths
            memory.imageLocalPaths = localPaths
        }

        try persistModelChangesIfNeeded()

        // Recompute weekly letters for all affected weeks.
        for weekStart in affectedWeekStarts {
            onMemoryPulled?(weekStart)
        }

        // Step 5: Save cursor only after all applies succeed.
        cursor.babyProfilesAt = upperBound
        cursor.recordItemsAt = upperBound
        cursor.memoryEntriesAt = upperBound
        cursorStore.save(cursor, for: userID)
    }

    /// Returns the applied `BabyProfile` (or `nil` if skipped/deleted).
    @discardableResult
    private func apply(_ remote: BabyProfileDTO) throws -> BabyProfile? {
        let existing = try fetchLocalBaby(id: remote.id)

        if let existing {
            // Skip rows where local is dirty.
            guard existing.syncState != .pendingUpsert else { return nil }

            // If remote is soft-deleted, remove local row.
            if remote.deletedAt != nil {
                modelContext.delete(existing)
                return nil
            }

            // Overwrite local fields with server truth.
            existing.name = remote.name
            existing.birthDate = remote.birthDate
            existing.gender = remote.gender.flatMap { BabyProfile.Gender(rawValue: $0) }
            existing.isActive = remote.isActive
            existing.hasCompletedOnboarding = remote.hasCompletedOnboarding
            existing.remoteAvatarPath = remote.avatarStoragePath
            existing.remoteVersion = remote.version
            existing.syncState = .synced
            return existing
        } else {
            // No local row exists. Skip if remote is soft-deleted.
            guard remote.deletedAt == nil else { return nil }

            let baby = BabyProfile(
                id: remote.id,
                name: remote.name,
                birthDate: remote.birthDate,
                gender: remote.gender.flatMap { BabyProfile.Gender(rawValue: $0) },
                createdAt: remote.createdAt,
                avatarPath: nil,
                remoteAvatarPath: remote.avatarStoragePath,
                remoteVersion: remote.version,
                syncStateRaw: SyncState.synced.rawValue,
                isActive: remote.isActive,
                hasCompletedOnboarding: remote.hasCompletedOnboarding
            )
            modelContext.insert(baby)
            return baby
        }
    }

    /// Returns the applied `RecordItem` (or `nil` if skipped/deleted).
    @discardableResult
    private func apply(_ remote: RecordItemDTO) throws -> RecordItem? {
        let existing = try fetchLocalRecord(id: remote.id)

        if let existing {
            guard existing.syncState != .pendingUpsert else { return nil }

            if remote.deletedAt != nil {
                modelContext.delete(existing)
                return nil
            }

            existing.babyID = remote.babyID
            existing.timestamp = remote.timestamp
            existing.type = remote.type
            existing.value = remote.value
            existing.leftNursingSeconds = remote.leftNursingSeconds
            existing.rightNursingSeconds = remote.rightNursingSeconds
            existing.subType = remote.subType
            existing.remoteImagePath = remote.imageStoragePath
            existing.aiSummary = remote.aiSummary
            existing.tags = remote.tags
            existing.note = remote.note
            existing.remoteVersion = remote.version
            existing.syncState = .synced
            return existing
        } else {
            guard remote.deletedAt == nil else { return nil }

            let record = RecordItem(
                id: remote.id,
                babyID: remote.babyID,
                timestamp: remote.timestamp,
                type: remote.type,
                value: remote.value,
                leftNursingSeconds: remote.leftNursingSeconds,
                rightNursingSeconds: remote.rightNursingSeconds,
                subType: remote.subType,
                imageURL: nil,
                remoteImagePath: remote.imageStoragePath,
                remoteVersion: remote.version,
                syncStateRaw: SyncState.synced.rawValue,
                aiSummary: remote.aiSummary,
                tags: remote.tags,
                note: remote.note
            )
            modelContext.insert(record)
            return record
        }
    }

    /// Returns `(wasInsertedOrDeleted, appliedMemoryEntry)`.
    /// `wasInsertedOrDeleted` is true when weekly letter recompute is needed.
    /// `appliedMemoryEntry` is non-nil when the entry exists locally after apply.
    @discardableResult
    private func apply(_ remote: MemoryEntryDTO) throws -> (Bool, MemoryEntry?) {
        let existing = try fetchLocalMemory(id: remote.id)

        if let existing {
            guard existing.syncState != .pendingUpsert else { return (false, nil) }

            if remote.deletedAt != nil {
                modelContext.delete(existing)
                return (true, nil)
            }

            existing.babyID = remote.babyID
            existing.createdAt = remote.createdAt
            existing.ageInDays = remote.ageInDays
            existing.remoteImagePaths = remote.imageStoragePaths
            existing.note = remote.note
            existing.isMilestone = remote.isMilestone
            existing.remoteVersion = remote.version
            existing.syncState = .synced
            return (true, existing)
        } else {
            guard remote.deletedAt == nil else { return (false, nil) }

            let entry = MemoryEntry(
                id: remote.id,
                babyID: remote.babyID,
                createdAt: remote.createdAt,
                ageInDays: remote.ageInDays,
                imageLocalPaths: [],
                remoteImagePathsPayload: nil,
                remoteVersion: remote.version,
                syncStateRaw: SyncState.synced.rawValue,
                note: remote.note,
                isMilestone: remote.isMilestone
            )
            entry.remoteImagePaths = remote.imageStoragePaths
            modelContext.insert(entry)
            return (true, entry)
        }
    }

    private func fetchLocalBaby(id: UUID) throws -> BabyProfile? {
        var descriptor = FetchDescriptor<BabyProfile>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchLocalRecord(id: UUID) throws -> RecordItem? {
        var descriptor = FetchDescriptor<RecordItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchLocalMemory(id: UUID) throws -> MemoryEntry? {
        var descriptor = FetchDescriptor<MemoryEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
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
