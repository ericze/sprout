//
//  SproutApp.swift
//  sprout
//
//  Created by ze on 21/3/26.
//

import SwiftUI
import SwiftData

@main
struct SproutApp: App {
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if isRunningTests {
                TestHostView()
            } else {
                switch AppState.current.containerResult {
                case .success(let container):
                    AppRootView(
                        container: container,
                        hasCompletedOnboarding: hasCompletedOnboarding
                    )
                case .failure(let errorMessage):
                    AppStartupErrorView(errorMessage: errorMessage)
                }
            }
        }
    }
}

// MARK: - Locale Environment Helper

/// Convenience modifier that forces the SwiftUI environment locale
/// to match `AppLanguageManager.shared.language`.  Applied at the root
/// so that all views inherit the correct locale without wrapping
/// individual sheets / pages.
struct AppLocaleModifier: ViewModifier {
    private let languageManager = AppLanguageManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.locale, languageManager.language.locale)
            .id(languageManager.languageVersion)
    }
}

extension View {
    func appLocaleAware() -> some View {
        modifier(AppLocaleModifier())
    }
}

// MARK: - App Root View

struct AppRootView: View {
    let container: ModelContainer
    let hasCompletedOnboarding: Bool

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                ContentView()
            }
        }
        .modelContainer(container)
        .appLocaleAware()
    }
}

// MARK: - App State

struct AppState {
    enum ContainerResult {
        case success(ModelContainer)
        case failure(String)
    }

    static let current = AppState(containerResult: makeContainerResult())

    let containerResult: ContainerResult

    private init(containerResult: ContainerResult) {
        self.containerResult = containerResult
    }

    static func makeContainerResult(
        schema: Schema? = nil,
        modelConfiguration: ModelConfiguration? = nil
    ) -> ContainerResult {
        let resolvedSchema = schema ?? SproutSchemaRegistry.schema
        let resolvedConfiguration = modelConfiguration ?? ModelConfiguration(
            schema: resolvedSchema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try SproutContainerFactory.make(
                schema: resolvedSchema,
                modelConfiguration: resolvedConfiguration
            )
            return .success(container)
        } catch {
            let nsError = error as NSError
            let diagnostic = "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)"
            return .failure(diagnostic)
        }
    }
}

// MARK: - Test Host

private struct TestHostView: View {
    var body: some View {
        Color.clear
    }
}
