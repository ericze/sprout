import Foundation

enum SyncReason: String, Codable, Equatable, Sendable {
    case appLaunch
    case authentication
    case manual
    case debouncedWrite
}
