import Foundation
import Observation

enum AuthManagerError: LocalizedError, Equatable {
    case accountBindingConflict(linkedUserID: UUID, incomingUserID: UUID)
    case invalidCredentials
    case noPendingAccountSwitch

    var errorDescription: String? {
        switch self {
        case let .accountBindingConflict(linkedUserID, incomingUserID):
            return "Account binding conflict. Linked user: \(linkedUserID.uuidString), incoming user: \(incomingUserID.uuidString)."
        case .invalidCredentials:
            return L10n.text(
                "account.error.invalid_credentials",
                en: "That email and password did not match. Please check them and try again.",
                zh: "邮箱和密码没有匹配成功。请检查后再试一次。"
            )
        case .noPendingAccountSwitch:
            return L10n.text(
                "account.error.no_pending_switch",
                en: "There is no pending account switch to confirm.",
                zh: "当前没有需要确认的账号切换。"
            )
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
            authState = .authenticated(userID: incomingUserID)
            triggerSyncHook(.appLaunch)
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

    func resetPassword(email: String) async throws {
        do {
            try await supabaseService.resetPassword(email: email)
        } catch {
            let mappedError = Self.mapAuthError(error)
            authState = .error(mappedError.localizedDescription)
            throw mappedError
        }
    }

    func signOut() async throws {
        try await supabaseService.signOut()
        currentUser = nil
        authState = .unauthenticated
    }

    func switchBindingToCurrentUser() async throws {
        guard case .blockedByAccountBinding = authState, let currentUser else {
            throw AuthManagerError.noPendingAccountSwitch
        }

        linkedUserID = currentUser.id
        defaults.set(currentUser.id.uuidString.lowercased(), forKey: linkedUserIDStorageKey)
        runLocalBootstrapper()
        authState = .authenticated(userID: currentUser.id)
        triggerSyncHook(.authentication)
    }

    private func authenticate(operation: () async throws -> SupabaseSession) async throws {
        authState = .authenticating

        do {
            let session = try await operation()
            try await finalizeAuthenticatedSession(session, syncReason: .authentication)
        } catch let authError as AuthManagerError {
            if case .accountBindingConflict = authError {
                throw authError
            }
            authState = .error(authError.localizedDescription)
            throw authError
        } catch {
            let mappedError = Self.mapAuthError(error)
            authState = .error(mappedError.localizedDescription)
            throw mappedError
        }
    }

    private func finalizeAuthenticatedSession(_ session: SupabaseSession, syncReason: SyncReason) async throws {
        let incomingUserID = session.user.id

        guard isBindingAllowed(for: incomingUserID) else {
            let linkedID = linkedUserID ?? incomingUserID
            currentUser = session.user
            authState = .blockedByAccountBinding
            throw AuthManagerError.accountBindingConflict(linkedUserID: linkedID, incomingUserID: incomingUserID)
        }

        persistLinkedUserIDIfNeeded(incomingUserID)
        currentUser = session.user
        runLocalBootstrapper()
        authState = .authenticated(userID: incomingUserID)
        triggerSyncHook(syncReason)
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

    private static func mapAuthError(_ error: Error) -> Error {
        if let authError = error as? AuthManagerError {
            return authError
        }

        let description = error.localizedDescription.lowercased()
        if description.contains("invalid login credentials")
            || description.contains("invalid credentials")
            || description.contains("invalid email or password")
        {
            return AuthManagerError.invalidCredentials
        }

        return error
    }
}
