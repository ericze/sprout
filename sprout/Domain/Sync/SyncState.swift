import Foundation

enum SyncState: String, Codable, CaseIterable, Sendable {
    case synced
    case pendingUpsert
}
