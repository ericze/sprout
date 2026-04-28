import Foundation
import Testing
@testable import sprout

@MainActor
struct RealSupabaseServiceSmokeTests {
    @Test("real Supabase auth smoke is gated by environment")
    func realAuthSmoke() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["SPROUT_REAL_SUPABASE_SMOKE"] == "1" else {
            return
        }

        let url = try #require(environment["SPROUT_SUPABASE_URL"])
        let anonKey = try #require(environment["SPROUT_SUPABASE_ANON_KEY"])
        let email = try #require(environment["SPROUT_SUPABASE_TEST_EMAIL"])
        let password = try #require(environment["SPROUT_SUPABASE_TEST_PASSWORD"])

        let service = try SupabaseService(
            config: SupabaseConfig(
                infoDictionary: [
                    SupabaseConfig.urlKey: url,
                    SupabaseConfig.anonKeyKey: anonKey
                ]
            )
        )

        let session = try await service.signIn(email: email, password: password)
        #expect(session.user.email == email)
        try await service.signOut()
    }
}
