import Foundation

struct SupabaseConfig: Equatable, Sendable {
    static let urlKey = "SUPABASE_URL"
    static let anonKeyKey = "SUPABASE_ANON_KEY"

    let url: URL
    let anonKey: String

    init(bundle: Bundle = .main) throws {
        try self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) throws {
        let urlString = try Self.requiredString(for: Self.urlKey, in: infoDictionary)
        guard let url = URL(string: urlString), let scheme = url.scheme, let host = url.host, !scheme.isEmpty, !host.isEmpty else {
            throw SupabaseConfigError.invalidURL(urlString)
        }
        guard !Self.isRestEndpointURL(url) else {
            throw SupabaseConfigError.invalidURL(urlString)
        }

        self.url = url
        self.anonKey = try Self.requiredString(for: Self.anonKeyKey, in: infoDictionary)
    }

    private static func isRestEndpointURL(_ url: URL) -> Bool {
        url.pathComponents.map { $0.lowercased() } == ["/", "rest", "v1"]
    }

    private static func requiredString(for key: String, in infoDictionary: [String: Any]) throws -> String {
        guard let value = infoDictionary[key] as? String else {
            throw SupabaseConfigError.missingValue(key)
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            throw SupabaseConfigError.missingValue(key)
        }

        return trimmedValue
    }
}

enum SupabaseConfigError: LocalizedError, Equatable {
    case missingValue(String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            return "Missing required Supabase configuration value: \(key)"
        case .invalidURL(let value):
            return "Invalid Supabase URL: \(value)"
        }
    }
}
