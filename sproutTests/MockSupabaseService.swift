import Foundation
@testable import sprout

actor MockSupabaseService: SupabaseServicing {
    enum Operation: Equatable, Sendable {
        case upsertBabyProfile(id: UUID, expectedVersion: Int64?, avatarStoragePath: String?)
        case upsertRecordItem(id: UUID, expectedVersion: Int64?, imageStoragePath: String?)
        case upsertMemoryEntry(id: UUID, expectedVersion: Int64?, imageStoragePaths: [String])
        case softDelete(table: SupabaseTable, id: UUID, expectedVersion: Int64?)
        case resetPassword(email: String)
        case uploadAsset(bucket: StorageBucket, path: String, contentType: String)
        case deleteAsset(bucket: StorageBucket, path: String)
    }

    var session: SupabaseSession?
    var serverNow: Date
    var babyProfiles: [UUID: BabyProfileDTO]
    var recordItems: [UUID: RecordItemDTO]
    var memoryEntries: [UUID: MemoryEntryDTO]
    var deletedRows: [(SupabaseTable, UUID)]
    var storedAssets: [String: Data]
    var operations: [Operation]
    var passwordResetEmails: [String]
    private var forcedSignInResult: Result<SupabaseSession, Error>?
    private var forcedSignUpResult: Result<SupabaseSession, Error>?
    private var forcedResetPasswordError: Error?
    private var forcedServerNowError: Error?
    private var forcedBabyUpsertError: Error?
    private var forcedRecordUpsertError: Error?
    private var forcedMemoryUpsertError: Error?
    private var forcedSoftDeleteError: Error?
    private var signOutCount: Int

    init(
        session: SupabaseSession? = nil,
        serverNow: Date = .now,
        babyProfiles: [UUID: BabyProfileDTO] = [:],
        recordItems: [UUID: RecordItemDTO] = [:],
        memoryEntries: [UUID: MemoryEntryDTO] = [:]
    ) {
        self.session = session
        self.serverNow = serverNow
        self.babyProfiles = babyProfiles
        self.recordItems = recordItems
        self.memoryEntries = memoryEntries
        deletedRows = []
        storedAssets = [:]
        operations = []
        passwordResetEmails = []
        signOutCount = 0
    }

    func stubSignIn(result: Result<SupabaseSession, Error>?) {
        forcedSignInResult = result
    }

    func stubSignUp(result: Result<SupabaseSession, Error>?) {
        forcedSignUpResult = result
    }

    func stubResetPasswordError(_ error: Error?) {
        forcedResetPasswordError = error
    }

    func stubServerNowError(_ error: Error?) {
        forcedServerNowError = error
    }

    func stubBabyUpsertError(_ error: Error?) {
        forcedBabyUpsertError = error
    }

    func stubRecordUpsertError(_ error: Error?) {
        forcedRecordUpsertError = error
    }

    func stubMemoryUpsertError(_ error: Error?) {
        forcedMemoryUpsertError = error
    }

    func stubSoftDeleteError(_ error: Error?) {
        forcedSoftDeleteError = error
    }

    func readSignOutCount() -> Int {
        signOutCount
    }

    func readOperations() -> [Operation] {
        operations
    }

    func readPasswordResetEmails() -> [String] {
        passwordResetEmails
    }

    func storeAsset(key: String, data: Data) {
        storedAssets[key] = data
    }

    func restoreSession() async throws -> SupabaseSession? {
        session
    }

    func signIn(email: String, password: String) async throws -> SupabaseSession {
        if let forcedSignInResult {
            return try forcedSignInResult.get()
        }
        let user = SupabaseAuthUser(id: UUID(), email: email)
        let nextSession = SupabaseSession(user: user)
        session = nextSession
        return nextSession
    }

    func signUp(email: String, password: String) async throws -> SupabaseSession {
        if let forcedSignUpResult {
            return try forcedSignUpResult.get()
        }
        return try await signIn(email: email, password: password)
    }

    func resetPassword(email: String) async throws {
        if let forcedResetPasswordError {
            throw forcedResetPasswordError
        }
        passwordResetEmails.append(email)
        operations.append(.resetPassword(email: email))
    }

    func signOut() async throws {
        session = nil
        signOutCount += 1
    }

    func fetchServerNow() async throws -> Date {
        if let forcedServerNowError {
            throw forcedServerNowError
        }
        return serverNow
    }

    func upsertBabyProfile(_ profile: BabyProfileDTO, expectedVersion: Int64?) async throws -> BabyProfileDTO {
        if let forcedBabyUpsertError {
            throw forcedBabyUpsertError
        }
        operations.append(
            .upsertBabyProfile(
                id: profile.id,
                expectedVersion: expectedVersion,
                avatarStoragePath: profile.avatarStoragePath
            )
        )
        return try save(profile, in: &babyProfiles, expectedVersion: expectedVersion)
    }

    func upsertRecordItem(_ record: RecordItemDTO, expectedVersion: Int64?) async throws -> RecordItemDTO {
        if let forcedRecordUpsertError {
            throw forcedRecordUpsertError
        }
        operations.append(
            .upsertRecordItem(
                id: record.id,
                expectedVersion: expectedVersion,
                imageStoragePath: record.imageStoragePath
            )
        )
        return try save(record, in: &recordItems, expectedVersion: expectedVersion)
    }

    func upsertMemoryEntry(_ entry: MemoryEntryDTO, expectedVersion: Int64?) async throws -> MemoryEntryDTO {
        if let forcedMemoryUpsertError {
            throw forcedMemoryUpsertError
        }
        operations.append(
            .upsertMemoryEntry(
                id: entry.id,
                expectedVersion: expectedVersion,
                imageStoragePaths: entry.imageStoragePaths
            )
        )
        return try save(entry, in: &memoryEntries, expectedVersion: expectedVersion)
    }

    func fetchBabyProfiles(updatedAfter: Date?, upTo upperBound: Date) async throws -> [BabyProfileDTO] {
        filteredRows(from: Array(babyProfiles.values), updatedAfter: updatedAfter, upperBound: upperBound)
    }

    func fetchRecordItems(updatedAfter: Date?, upTo upperBound: Date) async throws -> [RecordItemDTO] {
        filteredRows(from: Array(recordItems.values), updatedAfter: updatedAfter, upperBound: upperBound)
    }

    func fetchMemoryEntries(updatedAfter: Date?, upTo upperBound: Date) async throws -> [MemoryEntryDTO] {
        filteredRows(from: Array(memoryEntries.values), updatedAfter: updatedAfter, upperBound: upperBound)
    }

    func softDelete(table: SupabaseTable, id: UUID, expectedVersion: Int64?) async throws {
        operations.append(.softDelete(table: table, id: id, expectedVersion: expectedVersion))
        if let forcedSoftDeleteError {
            throw forcedSoftDeleteError
        }
        try validateDeletion(table: table, id: id, expectedVersion: expectedVersion)
        deletedRows.append((table, id))
        switch table {
        case .babyProfiles:
            babyProfiles.removeValue(forKey: id)
        case .recordItems:
            recordItems.removeValue(forKey: id)
        case .memoryEntries:
            memoryEntries.removeValue(forKey: id)
        case .profiles:
            break
        }
    }

    func uploadAsset(data: Data, bucket: StorageBucket, path: String, contentType: String) async throws {
        operations.append(.uploadAsset(bucket: bucket, path: path, contentType: contentType))
        storedAssets[assetKey(bucket: bucket, path: path)] = data
    }

    func downloadAsset(bucket: StorageBucket, path: String) async throws -> Data {
        storedAssets[assetKey(bucket: bucket, path: path)] ?? Data()
    }

    func deleteAsset(bucket: StorageBucket, path: String) async throws {
        operations.append(.deleteAsset(bucket: bucket, path: path))
        storedAssets.removeValue(forKey: assetKey(bucket: bucket, path: path))
    }

    private func save<Row: VersionedRow>(
        _ row: Row,
        in storage: inout [UUID: Row],
        expectedVersion: Int64?
    ) throws -> Row {
        if let existing = storage[row.id] {
            guard expectedVersion == existing.version else {
                throw SyncEngineError.versionConflict(table: Row.table, id: row.id)
            }

            let nextVersion = existing.version + 1
            let saved = row.withVersion(nextVersion)
            storage[row.id] = saved
            return saved
        }

        guard expectedVersion == nil else {
            throw SyncEngineError.versionConflict(table: Row.table, id: row.id)
        }

        let saved = row.withVersion(max(row.version, 0) + 1)
        storage[row.id] = saved
        return saved
    }

    private func validateDeletion(table: SupabaseTable, id: UUID, expectedVersion: Int64?) throws {
        switch table {
        case .babyProfiles:
            guard let row = babyProfiles[id] else { return }
            guard expectedVersion == row.version else {
                throw SyncEngineError.versionConflict(table: table, id: id)
            }
        case .recordItems:
            guard let row = recordItems[id] else { return }
            guard expectedVersion == row.version else {
                throw SyncEngineError.versionConflict(table: table, id: id)
            }
        case .memoryEntries:
            guard let row = memoryEntries[id] else { return }
            guard expectedVersion == row.version else {
                throw SyncEngineError.versionConflict(table: table, id: id)
            }
        case .profiles:
            break
        }
    }

    private func filteredRows<Row: Sendable>(
        from rows: [Row],
        updatedAfter: Date?,
        upperBound: Date
    ) -> [Row] where Row: HasUpdatedAt, Row: HasUUID {
        rows
            .filter { row in
                let isAfterLowerBound = updatedAfter.map { row.updatedAt > $0 } ?? true
                return isAfterLowerBound && row.updatedAt <= upperBound
            }
            .sorted {
                if $0.updatedAt == $1.updatedAt {
                    return $0.uuid.uuidString < $1.uuid.uuidString
                }
                return $0.updatedAt < $1.updatedAt
            }
    }

    private func assetKey(bucket: StorageBucket, path: String) -> String {
        "\(bucket.rawValue)::\(path)"
    }
}

private protocol VersionedRow: HasUpdatedAt, HasUUID {
    static var table: SupabaseTable { get }
    var id: UUID { get }
    var version: Int64 { get }
    func withVersion(_ version: Int64) -> Self
}

private protocol HasUpdatedAt {
    var updatedAt: Date { get }
}

private protocol HasUUID {
    var uuid: UUID { get }
}

extension BabyProfileDTO: HasUpdatedAt, HasUUID {
    var uuid: UUID { id }
}

extension BabyProfileDTO: VersionedRow {
    static var table: SupabaseTable { .babyProfiles }

    func withVersion(_ version: Int64) -> BabyProfileDTO {
        BabyProfileDTO(
            id: id,
            userID: userID,
            name: name,
            birthDate: birthDate,
            gender: gender,
            avatarStoragePath: avatarStoragePath,
            isActive: isActive,
            hasCompletedOnboarding: hasCompletedOnboarding,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
            deletedAt: deletedAt
        )
    }
}

extension RecordItemDTO: HasUpdatedAt, HasUUID {
    var uuid: UUID { id }
}

extension RecordItemDTO: VersionedRow {
    static var table: SupabaseTable { .recordItems }

    func withVersion(_ version: Int64) -> RecordItemDTO {
        RecordItemDTO(
            id: id,
            userID: userID,
            babyID: babyID,
            type: type,
            timestamp: timestamp,
            value: value,
            leftNursingSeconds: leftNursingSeconds,
            rightNursingSeconds: rightNursingSeconds,
            subType: subType,
            imageStoragePath: imageStoragePath,
            aiSummary: aiSummary,
            tags: tags,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
            deletedAt: deletedAt
        )
    }
}

extension MemoryEntryDTO: HasUpdatedAt, HasUUID {
    var uuid: UUID { id }
}

extension MemoryEntryDTO: VersionedRow {
    static var table: SupabaseTable { .memoryEntries }

    func withVersion(_ version: Int64) -> MemoryEntryDTO {
        MemoryEntryDTO(
            id: id,
            userID: userID,
            babyID: babyID,
            createdAt: createdAt,
            ageInDays: ageInDays,
            imageStoragePaths: imageStoragePaths,
            note: note,
            isMilestone: isMilestone,
            updatedAt: updatedAt,
            version: version,
            deletedAt: deletedAt
        )
    }
}
