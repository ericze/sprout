import Foundation
import Testing
@testable import sprout

@MainActor
struct AuthManagerTests {
    @Test("signIn binds first account and triggers bootstrap plus authentication sync hook")
    func signInBindsAccountAndTriggersHooks() async throws {
        let defaults = makeIsolatedDefaults()
        let userID = UUID()
        let session = SupabaseSession(user: SupabaseAuthUser(id: userID, email: "first@example.com"))
        let mockService = MockSupabaseService()
        await mockService.stubSignIn(result: .success(session))

        var bootstrapCalls = 0
        var syncReasons: [SyncReason] = []
        let manager = AuthManager(
            supabaseService: mockService,
            defaults: defaults,
            linkedUserIDStorageKey: "auth.linked.id.test",
            runLocalBootstrapper: { bootstrapCalls += 1 },
            triggerSyncHook: { syncReasons.append($0) }
        )

        try await manager.signIn(email: "first@example.com", password: "password")

        #expect(manager.authState == .authenticated(userID: userID))
        #expect(manager.currentUser?.id == userID)
        #expect(manager.linkedUserID == userID)
        #expect(bootstrapCalls == 1)
        #expect(syncReasons == [.authentication])
        #expect(await mockService.readSignOutCount() == 0)
    }

    @Test("signIn with a different linked account moves to blockedByAccountBinding and keeps local binding")
    func signInMismatchedAccountBecomesBlocked() async throws {
        let defaults = makeIsolatedDefaults()
        let linkedUserID = UUID()
        defaults.set(linkedUserID.uuidString.lowercased(), forKey: "auth.linked.id.test")

        let incomingUserID = UUID()
        let session = SupabaseSession(user: SupabaseAuthUser(id: incomingUserID, email: "incoming@example.com"))
        let mockService = MockSupabaseService()
        await mockService.stubSignIn(result: .success(session))

        var bootstrapCalls = 0
        var syncReasons: [SyncReason] = []
        let manager = AuthManager(
            supabaseService: mockService,
            defaults: defaults,
            linkedUserIDStorageKey: "auth.linked.id.test",
            runLocalBootstrapper: { bootstrapCalls += 1 },
            triggerSyncHook: { syncReasons.append($0) }
        )

        do {
            try await manager.signIn(email: "incoming@example.com", password: "password")
            Issue.record("Expected account binding conflict")
        } catch let error as AuthManagerError {
            #expect(error == .accountBindingConflict(linkedUserID: linkedUserID, incomingUserID: incomingUserID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(manager.authState == .blockedByAccountBinding)
        #expect(manager.currentUser?.id == incomingUserID)
        #expect(manager.linkedUserID == linkedUserID)
        #expect(bootstrapCalls == 0)
        #expect(syncReasons.isEmpty)
        #expect(await mockService.readSignOutCount() == 1)
    }

    @Test("restoreSession with matching account bootstraps and triggers appLaunch sync hook")
    func restoreSessionMatchingAccount() async {
        let defaults = makeIsolatedDefaults()
        let userID = UUID()
        let session = SupabaseSession(user: SupabaseAuthUser(id: userID, email: "restore@example.com"))
        let mockService = MockSupabaseService(session: session)

        var bootstrapCalls = 0
        var syncReasons: [SyncReason] = []
        let manager = AuthManager(
            supabaseService: mockService,
            defaults: defaults,
            linkedUserIDStorageKey: "auth.linked.id.test",
            runLocalBootstrapper: { bootstrapCalls += 1 },
            triggerSyncHook: { syncReasons.append($0) }
        )

        await manager.restoreSession()

        #expect(manager.authState == .authenticated(userID: userID))
        #expect(manager.currentUser?.id == userID)
        #expect(manager.linkedUserID == userID)
        #expect(bootstrapCalls == 1)
        #expect(syncReasons == [.appLaunch])
    }

    @Test("restoreSession with mismatched linked user is blocked without triggering bootstrap or sync")
    func restoreSessionMismatchedAccount() async {
        let defaults = makeIsolatedDefaults()
        let linkedUserID = UUID()
        defaults.set(linkedUserID.uuidString.lowercased(), forKey: "auth.linked.id.test")

        let incomingUserID = UUID()
        let session = SupabaseSession(user: SupabaseAuthUser(id: incomingUserID, email: "restore-mismatch@example.com"))
        let mockService = MockSupabaseService(session: session)

        var bootstrapCalls = 0
        var syncReasons: [SyncReason] = []
        let manager = AuthManager(
            supabaseService: mockService,
            defaults: defaults,
            linkedUserIDStorageKey: "auth.linked.id.test",
            runLocalBootstrapper: { bootstrapCalls += 1 },
            triggerSyncHook: { syncReasons.append($0) }
        )

        await manager.restoreSession()

        #expect(manager.authState == .blockedByAccountBinding)
        #expect(manager.currentUser?.id == incomingUserID)
        #expect(manager.linkedUserID == linkedUserID)
        #expect(bootstrapCalls == 0)
        #expect(syncReasons.isEmpty)
    }

    @Test("signOut resets auth state but keeps linked user binding")
    func signOutDoesNotClearBinding() async throws {
        let defaults = makeIsolatedDefaults()
        let userID = UUID()
        let session = SupabaseSession(user: SupabaseAuthUser(id: userID, email: "signout@example.com"))
        let mockService = MockSupabaseService()
        await mockService.stubSignIn(result: .success(session))

        let manager = AuthManager(
            supabaseService: mockService,
            defaults: defaults,
            linkedUserIDStorageKey: "auth.linked.id.test"
        )

        try await manager.signIn(email: "signout@example.com", password: "password")
        try await manager.signOut()

        #expect(manager.authState == .unauthenticated)
        #expect(manager.currentUser == nil)
        #expect(manager.linkedUserID == userID)
    }

    @Test("signUp failure transitions state to error")
    func signUpFailureSetsErrorState() async {
        let defaults = makeIsolatedDefaults()
        let mockService = MockSupabaseService()
        await mockService.stubSignUp(result: .failure(StubAuthError.boom))

        let manager = AuthManager(
            supabaseService: mockService,
            defaults: defaults,
            linkedUserIDStorageKey: "auth.linked.id.test"
        )

        do {
            try await manager.signUp(email: "new@example.com", password: "password")
            Issue.record("Expected signUp to throw")
        } catch {}

        #expect(manager.authState == .error("boom"))
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "auth-manager-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private enum StubAuthError: LocalizedError {
    case boom

    var errorDescription: String? {
        "boom"
    }
}
