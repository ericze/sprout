import Testing
@testable import sprout

struct SupabaseConfigTests {
    @Test("SupabaseConfig reads required values from an info dictionary")
    func readsValues() throws {
        let config = try SupabaseConfig(
            infoDictionary: [
                SupabaseConfig.urlKey: "https://example.supabase.co",
                SupabaseConfig.anonKeyKey: "anon-key",
            ]
        )

        #expect(config.url.absoluteString == "https://example.supabase.co")
        #expect(config.anonKey == "anon-key")
    }

    @Test("SupabaseConfig rejects missing values")
    func rejectsMissingValues() {
        #expect(throws: SupabaseConfigError.missingValue(SupabaseConfig.urlKey)) {
            _ = try SupabaseConfig(infoDictionary: [SupabaseConfig.anonKeyKey: "anon-key"])
        }
    }

    @Test("SupabaseConfig rejects invalid URLs")
    func rejectsInvalidURL() {
        #expect(throws: SupabaseConfigError.invalidURL("not-a-url")) {
            _ = try SupabaseConfig(
                infoDictionary: [
                    SupabaseConfig.urlKey: "not-a-url",
                    SupabaseConfig.anonKeyKey: "anon-key",
                ]
            )
        }
    }

    @Test("SupabaseConfig rejects REST endpoint URLs")
    func rejectsRestEndpointURL() {
        #expect(throws: SupabaseConfigError.invalidURL("https://example.supabase.co/rest/v1/")) {
            _ = try SupabaseConfig(
                infoDictionary: [
                    SupabaseConfig.urlKey: "https://example.supabase.co/rest/v1/",
                    SupabaseConfig.anonKeyKey: "anon-key",
                ]
            )
        }
    }
}
