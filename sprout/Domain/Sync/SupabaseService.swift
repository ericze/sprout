import Foundation

#if canImport(Supabase)
import Supabase
#endif

enum SupabaseServiceError: LocalizedError, Equatable {
    case sdkUnavailable
    case notImplemented(String)
    case signUpRequiresEmailConfirmation

    var errorDescription: String? {
        switch self {
        case .sdkUnavailable:
            return "Supabase SDK is not available in the current build."
        case .notImplemented(let operation):
            return "Supabase operation is not implemented yet: \(operation)"
        case .signUpRequiresEmailConfirmation:
            return "Sign up requires email confirmation before a session is available."
        }
    }
}

protocol SupabaseServicing: Sendable {
    func restoreSession() async throws -> SupabaseSession?
    func signIn(email: String, password: String) async throws -> SupabaseSession
    func signUp(email: String, password: String) async throws -> SupabaseSession
    func signOut() async throws
    func fetchServerNow() async throws -> Date
    func upsertBabyProfile(_ profile: BabyProfileDTO, expectedVersion: Int64?) async throws -> BabyProfileDTO
    func upsertRecordItem(_ record: RecordItemDTO, expectedVersion: Int64?) async throws -> RecordItemDTO
    func upsertMemoryEntry(_ entry: MemoryEntryDTO, expectedVersion: Int64?) async throws -> MemoryEntryDTO
    func fetchBabyProfiles(updatedAfter: Date?, upTo upperBound: Date) async throws -> [BabyProfileDTO]
    func fetchRecordItems(updatedAfter: Date?, upTo upperBound: Date) async throws -> [RecordItemDTO]
    func fetchMemoryEntries(updatedAfter: Date?, upTo upperBound: Date) async throws -> [MemoryEntryDTO]
    func softDelete(table: SupabaseTable, id: UUID, expectedVersion: Int64?) async throws
    func uploadAsset(data: Data, bucket: StorageBucket, path: String, contentType: String) async throws
    func downloadAsset(bucket: StorageBucket, path: String) async throws -> Data
    func deleteAsset(bucket: StorageBucket, path: String) async throws
}

actor SupabaseService: SupabaseServicing {
    let config: SupabaseConfig

    #if canImport(Supabase)
    private let client: SupabaseClient
    #endif

    init(config: SupabaseConfig) {
        self.config = config
        #if canImport(Supabase)
        client = SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey
        )
        #endif
    }

    func restoreSession() async throws -> SupabaseSession? {
        #if canImport(Supabase)
        do {
            return makeSession(try await client.auth.session)
        } catch {
            return nil
        }
        #else
        throw unavailable("restoreSession")
        #endif
    }

    func signIn(email: String, password: String) async throws -> SupabaseSession {
        #if canImport(Supabase)
        let session = try await client.auth.signIn(email: email, password: password)
        return makeSession(session)
        #else
        throw unavailable("signIn")
        #endif
    }

    func signUp(email: String, password: String) async throws -> SupabaseSession {
        #if canImport(Supabase)
        let response = try await client.auth.signUp(email: email, password: password)
        guard let session = response.session else {
            throw SupabaseServiceError.signUpRequiresEmailConfirmation
        }
        return makeSession(session)
        #else
        throw unavailable("signUp")
        #endif
    }

    func signOut() async throws {
        #if canImport(Supabase)
        try await client.auth.signOut()
        #else
        throw unavailable("signOut")
        #endif
    }

    func fetchServerNow() async throws -> Date {
        #if canImport(Supabase)
        let response: PostgrestResponse<Date> = try await client
            .rpc("server_now")
            .execute()
        return response.value
        #else
        throw unavailable("fetchServerNow")
        #endif
    }

    func upsertBabyProfile(_ profile: BabyProfileDTO, expectedVersion: Int64?) async throws -> BabyProfileDTO {
        try await upsert(
            function: "upsert_baby_profile",
            table: .babyProfiles,
            rowID: profile.id,
            payload: profile,
            expectedVersion: expectedVersion
        )
    }

    func upsertRecordItem(_ record: RecordItemDTO, expectedVersion: Int64?) async throws -> RecordItemDTO {
        try await upsert(
            function: "upsert_record_item",
            table: .recordItems,
            rowID: record.id,
            payload: record,
            expectedVersion: expectedVersion
        )
    }

    func upsertMemoryEntry(_ entry: MemoryEntryDTO, expectedVersion: Int64?) async throws -> MemoryEntryDTO {
        try await upsert(
            function: "upsert_memory_entry",
            table: .memoryEntries,
            rowID: entry.id,
            payload: entry,
            expectedVersion: expectedVersion
        )
    }

    func fetchBabyProfiles(updatedAfter: Date?, upTo upperBound: Date) async throws -> [BabyProfileDTO] {
        try await fetchRows(
            table: SupabaseTable.babyProfiles.rawValue,
            updatedAfter: updatedAfter,
            upperBound: upperBound
        )
    }

    func fetchRecordItems(updatedAfter: Date?, upTo upperBound: Date) async throws -> [RecordItemDTO] {
        try await fetchRows(
            table: SupabaseTable.recordItems.rawValue,
            updatedAfter: updatedAfter,
            upperBound: upperBound
        )
    }

    func fetchMemoryEntries(updatedAfter: Date?, upTo upperBound: Date) async throws -> [MemoryEntryDTO] {
        try await fetchRows(
            table: SupabaseTable.memoryEntries.rawValue,
            updatedAfter: updatedAfter,
            upperBound: upperBound
        )
    }

    func softDelete(table: SupabaseTable, id: UUID, expectedVersion: Int64?) async throws {
        #if canImport(Supabase)
        do {
            _ = try await client
                .rpc(
                    "soft_delete_row",
                    params: SoftDeleteParams(
                        tableName: table.rawValue,
                        rowID: id,
                        expectedVersion: expectedVersion
                    )
                )
                .execute()
        } catch {
            throw mapPostgrestError(error, table: table, id: id)
        }
        #else
        throw unavailable("softDelete")
        #endif
    }

    func uploadAsset(data: Data, bucket: StorageBucket, path: String, contentType: String) async throws {
        #if canImport(Supabase)
        let file = client.storage.from(bucket.rawValue)
        do {
            _ = try await file.upload(
                path,
                data: data,
                options: FileOptions(contentType: contentType, upsert: false)
            )
        } catch {
            _ = try await file.update(
                path,
                data: data,
                options: FileOptions(contentType: contentType, upsert: true)
            )
        }
        #else
        throw unavailable("uploadAsset")
        #endif
    }

    func downloadAsset(bucket: StorageBucket, path: String) async throws -> Data {
        #if canImport(Supabase)
        try await client.storage.from(bucket.rawValue).download(path: path)
        #else
        throw unavailable("downloadAsset")
        #endif
    }

    func deleteAsset(bucket: StorageBucket, path: String) async throws {
        #if canImport(Supabase)
        _ = try await client.storage.from(bucket.rawValue).remove(paths: [path])
        #else
        throw unavailable("deleteAsset")
        #endif
    }

    private func unavailable(_ operation: String) -> SupabaseServiceError {
        #if canImport(Supabase)
        return .notImplemented(operation)
        #else
        return .sdkUnavailable
        #endif
    }

    static func make(bundle: Bundle = .main) throws -> SupabaseService {
        try SupabaseService(config: SupabaseConfig(bundle: bundle))
    }
}

#if canImport(Supabase)
private extension SupabaseService {
    func makeSession(_ session: Session) -> SupabaseSession {
        SupabaseSession(
            user: SupabaseAuthUser(
                id: session.user.id,
                email: session.user.email
            )
        )
    }

    func upsert<Row: Codable & Sendable>(
        function: String,
        table: SupabaseTable,
        rowID: UUID,
        payload: Row,
        expectedVersion: Int64?
    ) async throws -> Row {
        do {
            let response: PostgrestResponse<Row> = try await client
                .rpc(function, params: RPCPayload(payload: payload, expectedVersion: expectedVersion))
                .single()
                .execute()
            return response.value
        } catch {
            throw mapPostgrestError(error, table: table, id: rowID)
        }
    }

    func fetchRows<Row: Decodable & Sendable>(
        table: String,
        updatedAfter: Date?,
        upperBound: Date
    ) async throws -> [Row] {
        let query = client
            .from(table)
            .select()
            .lte("updated_at", value: upperBound)
        _ = query.order("updated_at", ascending: true)
        _ = query.order("id", ascending: true)

        if let updatedAfter {
            _ = query.gt("updated_at", value: updatedAfter)
        }

        let response: PostgrestResponse<[Row]> = try await query.execute()
        return response.value
    }

    func mapPostgrestError(_ error: Error, table: SupabaseTable, id: UUID) -> Error {
        guard let postgrestError = error as? PostgrestError,
              postgrestError.code == "40001"
        else {
            return error
        }
        return SyncEngineError.versionConflict(table: table, id: id)
    }
}

private struct RPCPayload<Row: Encodable & Sendable>: nonisolated Encodable, Sendable {
    let payload: Row
    let expectedVersion: Int64?

    enum CodingKeys: String, CodingKey {
        case payload
        case expectedVersion = "expected_version"
    }
}

private struct SoftDeleteParams: nonisolated Encodable, Sendable {
    let tableName: String
    let rowID: UUID
    let expectedVersion: Int64?

    enum CodingKeys: String, CodingKey {
        case tableName = "table_name"
        case rowID = "row_id"
        case expectedVersion = "expected_version"
    }
}
#endif
