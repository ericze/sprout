import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    init(locale: Locale = .autoupdatingCurrent) {
        let languageCode = locale.language.languageCode?.identifier

        switch languageCode {
        case "zh":
            self = .simplifiedChinese
        default:
            self = .english
        }
    }

    static let fallback: AppLanguage = .english

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var lprojName: String {
        rawValue
    }
}

/// Singleton that owns the persisted app language and broadcasts changes.
/// - Persists to `UserDefaults` under `app_language`.
/// - Falls back to the device locale on first launch.
/// - Changing `language` also updates `LocalizationService.current` so
///   the rest of the app picks up the new locale immediately.
@MainActor
@Observable
final class AppLanguageManager {
    static let shared = AppLanguageManager()

    private static let defaultStorageKey = "app_language"

    private let defaults: UserDefaults
    private let storageKey: String

    /// A monotonically increasing version that increments on every language change.
    /// Views can use `.onChange(of: AppLanguageManager.shared.languageVersion)` to
    /// force a re-render when the language changes.
    var languageVersion: Int = 0

    var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            persistLanguage(language)
            languageVersion += 1
            LocalizationService.override(language: language)
        }
    }

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = Self.defaultStorageKey,
        initialLanguage: AppLanguage? = nil
    ) {
        self.defaults = defaults
        self.storageKey = storageKey

        let stored = defaults.string(forKey: storageKey)
        if let stored, let parsed = AppLanguage(rawValue: stored) {
            self.language = parsed
        } else {
            self.language = initialLanguage ?? AppLanguage(locale: .autoupdatingCurrent)
        }
        LocalizationService.override(language: self.language)
    }

    private func persistLanguage(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: storageKey)
    }
}
