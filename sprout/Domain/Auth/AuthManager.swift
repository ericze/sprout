import Foundation
import Observation

enum AuthManagerError: LocalizedError, Equatable {
    case accountBindingConflict(linkedUserID: UUID, incomingUserID: UUID)

    var errorDescription: String? {
        switch self {
        case let .accountBindingConflict(linkedUserID, incomingUserID):
            return "Account binding conflict. Linked user: \(linkedUserID.uuidString), incoming user: \(incomingUserID.uuidString)."
        }
    }
}

@MainActor
@Observable
final class AuthManager {
    private let supabaseService: any SupabaseServicing
    private let defaults: UserDefaults
    private let linkedUserIDStorageKey: String
    private let runLocalBootstrapper: @MainActor () -> Void
    private let triggerSyncHook: @MainActor (SyncReason) -> Void

    var currentUser: SupabaseAuthUser?
    var authState: AuthState = .unauthenticated
    private(set) var linkedUserID: UUID?

    init(
        supabaseService: any SupabaseServicing,
        defaults: UserDefaults = .standard,
        linkedUserIDStorageKey: String = "auth.linked_user_id",
        runLocalBootstrapper: @escaping @MainActor () -> Void = {},
        triggerSyncHook: @escaping @MainActor (SyncReason) -> Void = { _ in }
    ) {
        self.supabaseService = supabaseService
        self.defaults = defaults
        self.linkedUserIDStorageKey = linkedUserIDStorageKey
        self.runLocalBootstrapper = runLocalBootstrapper
        self.triggerSyncHook = triggerSyncHook
        linkedUserID = Self.loadLinkedUserID(defaults: defaults, key: linkedUserIDStorageKey)
    }

    func restoreSession() async {
        authState = .authenticating

        do {
            guard let session = try await supabaseService.restoreSession() else {
                currentUser = nil
                authState = .unauthenticated
                return
            }

            let incomingUserID = session.user.id
            guard isBindingAllowed(for: incomingUserID) else {
                currentUser = session.user
                authState = .blockedByAccountBinding
                return
            }

            persistLinkedUserIDIfNeeded(incomingUserID)
            currentUser = session.user
            runLocalBootstrapper()
            triggerSyncHook(.appLaunch)
            authState = .authenticated(userID: incomingUserID)
        } catch {
            currentUser = nil
            authState = .error(error.localizedDescription)
        }
    }

    func signIn(email: String, password: String) async throws {
        try await authenticate {
            try await supabaseService.signIn(email: email, password: password)
        }
    }

    func signUp(email: String, password: String) async throws {
        try await authenticate {
            try await supabaseService.signUp(email: email, password: password)
        }
    }

    func signOut() async throws {
        try await supabaseService.signOut()
        currentUser = nil
        authState = .unauthenticated
    }

    private func authenticate(operation: () async throws -> SupabaseSession) async throws {
        authState = .authenticating

        do {
            let session = try await operation()
            try await finalizeAuthenticatedSession(session, syncReason: .authentication)
        } catch let authError as AuthManagerError {
            throw authError
        } catch {
            authState = .error(error.localizedDescription)
            throw error
        }
    }

    private func finalizeAuthenticatedSession(_ session: SupabaseSession, syncReason: SyncReason) async throws {
        let incomingUserID = session.user.id

        guard isBindingAllowed(for: incomingUserID) else {
            let linkedID = linkedUserID ?? incomingUserID
            currentUser = session.user
            authState = .blockedByAccountBinding
            try? await supabaseService.signOut()
            throw AuthManagerError.accountBindingConflict(linkedUserID: linkedID, incomingUserID: incomingUserID)
        }

        persistLinkedUserIDIfNeeded(incomingUserID)
        currentUser = session.user
        runLocalBootstrapper()
        triggerSyncHook(syncReason)
        authState = .authenticated(userID: incomingUserID)
    }

    private func isBindingAllowed(for userID: UUID) -> Bool {
        guard let linkedUserID else { return true }
        return linkedUserID == userID
    }

    private func persistLinkedUserIDIfNeeded(_ userID: UUID) {
        guard linkedUserID == nil else { return }
        linkedUserID = userID
        defaults.set(userID.uuidString.lowercased(), forKey: linkedUserIDStorageKey)
    }

    private static func loadLinkedUserID(defaults: UserDefaults, key: String) -> UUID? {
        guard let rawValue = defaults.string(forKey: key) else { return nil }
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let parsed = UUID(uuidString: normalized) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return parsed
    }
}
