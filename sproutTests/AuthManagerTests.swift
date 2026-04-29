import Foundation
import SwiftData
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

    @Test("signIn publishes authenticated state before sync hook runs")
    func signInSetsAuthenticatedStateBeforeSyncHook() async throws {
        let defaults = makeIsolatedDefaults()
        let userID = UUID()
        let session = SupabaseSession(user: SupabaseAuthUser(id: userID, email: "ordered@example.com"))
        let mockService = MockSupabaseService()
        await mockService.stubSignIn(result: .success(session))

        var manager: AuthManager?
        var observedAuthState: AuthState?
        manager = AuthManager(
            supabaseService: mockService,
            defaults: defaults,
            linkedUserIDStorageKey: "auth.linked.id.test",
            triggerSyncHook: { _ in
                observedAuthState = manager?.authState
            }
        )

        try await manager?.signIn(email: "ordered@example.com", password: "password")

        #expect(observedAuthState == .authenticated(userID: userID))
    }

    @Test("signIn with a different linked account blocks without clearing the incoming session")
    func signInMismatchedAccountBecomesBlockedWithoutAutoSignOut() async throws {
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
            Issue.record(Comment(rawValue: "Expected account binding conflict"))
        } catch let error as AuthManagerError {
            #expect(error == .accountBindingConflict(linkedUserID: linkedUserID, incomingUserID: incomingUserID))
        } catch {
            Issue.record(error, Comment(rawValue: "Unexpected error"))
        }

        #expect(manager.authState == .blockedByAccountBinding)
        #expect(manager.currentUser?.id == incomingUserID)
        #expect(manager.linkedUserID == linkedUserID)
        #expect(bootstrapCalls == 0)
        #expect(syncReasons.isEmpty)
        #expect(await mockService.readSignOutCount() == 0)
    }

    @Test("confirmed account switch rebinds the device and triggers sync without deleting local data")
    func confirmedAccountSwitchRebindsDevice() async throws {
        let defaults = makeIsolatedDefaults()
        let linkedUserID = UUID()
        defaults.set(linkedUserID.uuidString.lowercased(), forKey: "auth.linked.id.test")

        let incomingUserID = UUID()
        let session = SupabaseSession(user: SupabaseAuthUser(id: incomingUserID, email: "new@example.com"))
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
            try await manager.signIn(email: "new@example.com", password: "password")
            Issue.record(Comment(rawValue: "Expected account binding conflict"))
        } catch let error as AuthManagerError {
            #expect(error == .accountBindingConflict(linkedUserID: linkedUserID, incomingUserID: incomingUserID))
        } catch {
            Issue.record(error, Comment(rawValue: "Unexpected error"))
        }

        try await manager.switchBindingToCurrentUser()

        #expect(manager.authState == .authenticated(userID: incomingUserID))
        #expect(manager.currentUser?.id == incomingUserID)
        #expect(manager.linkedUserID == incomingUserID)
        #expect(defaults.string(forKey: "auth.linked.id.test") == incomingUserID.uuidString.lowercased())
        #expect(bootstrapCalls == 1)
        #expect(syncReasons == [.authentication])
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

    @Test("signOut leaves local SwiftData records in place")
    func signOutDoesNotDeleteLocalData() async throws {
        let environment = try makeTestEnvironment(now: Date(timeIntervalSince1970: 1_711_600_000))
        let baby = BabyProfile(name: "Local Baby", birthDate: environment.now.value)
        environment.modelContext.insert(baby)
        try environment.modelContext.save()

        let defaults = makeIsolatedDefaults()
        let userID = UUID()
        let session = SupabaseSession(user: SupabaseAuthUser(id: userID, email: "local@example.com"))
        let mockService = MockSupabaseService()
        await mockService.stubSignIn(result: .success(session))
        let manager = AuthManager(
            supabaseService: mockService,
            defaults: defaults,
            linkedUserIDStorageKey: "auth.linked.id.test"
        )

        try await manager.signIn(email: "local@example.com", password: "password")
        try await manager.signOut()

        let babyID = baby.id
        var descriptor = FetchDescriptor<BabyProfile>(predicate: #Predicate { $0.id == babyID })
        descriptor.fetchLimit = 1
        let fetchedBaby = try environment.modelContext.fetch(descriptor).first
        #expect(fetchedBaby?.name == "Local Baby")
        #expect(manager.authState == .unauthenticated)
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
            Issue.record(Comment(rawValue: "Expected signUp to throw"))
        } catch {}

        #expect(manager.authState == .error("boom"))
    }

    @Test("invalid password failure uses calm user-facing copy")
    func invalidPasswordUsesUserFacingError() async {
        let defaults = makeIsolatedDefaults()
        let mockService = MockSupabaseService()
        await mockService.stubSignIn(result: .failure(StubAuthError.invalidCredentials))

        let manager = AuthManager(
            supabaseService: mockService,
            defaults: defaults,
            linkedUserIDStorageKey: "auth.linked.id.test"
        )

        do {
            try await manager.signIn(email: "wrong@example.com", password: "bad-password")
            Issue.record(Comment(rawValue: "Expected signIn to throw"))
        } catch let error as AuthManagerError {
            #expect(error == .invalidCredentials)
        } catch {
            Issue.record(error, Comment(rawValue: "Unexpected error"))
        }

        #expect(manager.authState == .error(AuthManagerError.invalidCredentials.localizedDescription))
    }

    @Test("reset password delegates to service and records a calm success state")
    func resetPasswordDelegatesToService() async throws {
        let defaults = makeIsolatedDefaults()
        let mockService = MockSupabaseService()
        let manager = AuthManager(
            supabaseService: mockService,
            defaults: defaults,
            linkedUserIDStorageKey: "auth.linked.id.test"
        )

        try await manager.resetPassword(email: "reset@example.com")

        #expect(await mockService.readPasswordResetEmails() == ["reset@example.com"])
        #expect(manager.authState == .unauthenticated)
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
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .boom:
            return "boom"
        case .invalidCredentials:
            return "Invalid login credentials"
        }
    }
}
