import Foundation
@testable import sprout

actor MockSupabaseService: SupabaseServicing {
    var session: SupabaseSession?
    var serverNow: Date
    var babyProfiles: [UUID: BabyProfileDTO]
    var recordItems: [UUID: RecordItemDTO]
    var memoryEntries: [UUID: MemoryEntryDTO]
    var deletedRows: [(SupabaseTable, UUID)]
    var storedAssets: [String: Data]
    private var forcedSignInResult: Result<SupabaseSession, Error>?
    private var forcedSignUpResult: Result<SupabaseSession, Error>?
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
        signOutCount = 0
    }

    func stubSignIn(result: Result<SupabaseSession, Error>?) {
        forcedSignInResult = result
    }

    func stubSignUp(result: Result<SupabaseSession, Error>?) {
        forcedSignUpResult = result
    }

    func readSignOutCount() -> Int {
        signOutCount
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

    func signOut() async throws {
        session = nil
        signOutCount += 1
    }

    func fetchServerNow() async throws -> Date {
        serverNow
    }

    func upsertBabyProfile(_ profile: BabyProfileDTO, expectedVersion: Int64?) async throws -> BabyProfileDTO {
        babyProfiles[profile.id] = profile
        return profile
    }

    func upsertRecordItem(_ record: RecordItemDTO, expectedVersion: Int64?) async throws -> RecordItemDTO {
        recordItems[record.id] = record
        return record
    }

    func upsertMemoryEntry(_ entry: MemoryEntryDTO, expectedVersion: Int64?) async throws -> MemoryEntryDTO {
        memoryEntries[entry.id] = entry
        return entry
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
        storedAssets[assetKey(bucket: bucket, path: path)] = data
    }

    func downloadAsset(bucket: StorageBucket, path: String) async throws -> Data {
        storedAssets[assetKey(bucket: bucket, path: path)] ?? Data()
    }

    func deleteAsset(bucket: StorageBucket, path: String) async throws {
        storedAssets.removeValue(forKey: assetKey(bucket: bucket, path: path))
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

private protocol HasUpdatedAt {
    var updatedAt: Date { get }
}

private protocol HasUUID {
    var uuid: UUID { get }
}

extension BabyProfileDTO: HasUpdatedAt, HasUUID {
    var uuid: UUID { id }
}

extension RecordItemDTO: HasUpdatedAt, HasUUID {
    var uuid: UUID { id }
}

extension MemoryEntryDTO: HasUpdatedAt, HasUUID {
    var uuid: UUID { id }
}
