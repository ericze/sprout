import Foundation

enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(userID: UUID)
    case blockedByAccountBinding
    case error(String)
}
