import Foundation

#if canImport(Supabase)
import Supabase
#endif

enum SupabaseServiceError: LocalizedError, Equatable {
    case sdkUnavailable
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .sdkUnavailable:
            return "Supabase SDK is not available in the current build."
        case .notImplemented(let operation):
            return "Supabase operation is not implemented yet: \(operation)"
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
        throw unavailable("restoreSession")
    }

    func signIn(email: String, password: String) async throws -> SupabaseSession {
        throw unavailable("signIn")
    }

    func signUp(email: String, password: String) async throws -> SupabaseSession {
        throw unavailable("signUp")
    }

    func signOut() async throws {
        throw unavailable("signOut")
    }

    func fetchServerNow() async throws -> Date {
        throw unavailable("fetchServerNow")
    }

    func upsertBabyProfile(_ profile: BabyProfileDTO, expectedVersion: Int64?) async throws -> BabyProfileDTO {
        throw unavailable("upsertBabyProfile")
    }

    func upsertRecordItem(_ record: RecordItemDTO, expectedVersion: Int64?) async throws -> RecordItemDTO {
        throw unavailable("upsertRecordItem")
    }

    func upsertMemoryEntry(_ entry: MemoryEntryDTO, expectedVersion: Int64?) async throws -> MemoryEntryDTO {
        throw unavailable("upsertMemoryEntry")
    }

    func fetchBabyProfiles(updatedAfter: Date?, upTo upperBound: Date) async throws -> [BabyProfileDTO] {
        throw unavailable("fetchBabyProfiles")
    }

    func fetchRecordItems(updatedAfter: Date?, upTo upperBound: Date) async throws -> [RecordItemDTO] {
        throw unavailable("fetchRecordItems")
    }

    func fetchMemoryEntries(updatedAfter: Date?, upTo upperBound: Date) async throws -> [MemoryEntryDTO] {
        throw unavailable("fetchMemoryEntries")
    }

    func softDelete(table: SupabaseTable, id: UUID, expectedVersion: Int64?) async throws {
        throw unavailable("softDelete")
    }

    func uploadAsset(data: Data, bucket: StorageBucket, path: String, contentType: String) async throws {
        throw unavailable("uploadAsset")
    }

    func downloadAsset(bucket: StorageBucket, path: String) async throws -> Data {
        throw unavailable("downloadAsset")
    }

    func deleteAsset(bucket: StorageBucket, path: String) async throws {
        throw unavailable("deleteAsset")
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
