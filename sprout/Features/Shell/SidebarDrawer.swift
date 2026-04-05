import SwiftUI

struct SidebarDrawer: View {
    let headerConfig: HomeHeaderConfig
    let babyRepository: BabyRepository
    @Binding var isNavigationAtRoot: Bool
    @Binding var isSidebarOpen: Bool
    let onHeaderTap: () -> Void

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            SidebarMenuView(
                headerConfig: headerConfig,
                onHeaderTap: onHeaderTap,
                onNavigate: { route in navigationPath.append(route) }
            )
            .navigationDestination(for: SidebarRoute.self) { route in
                switch route {
                case .babyProfile:
                    BabyProfileView(babyRepository: babyRepository)
                case .language:
                    LanguageRegionView(onLanguageChange: { newLanguage in
                        AppLanguageManager.shared.language = newLanguage
                    })
                }
            }
        }
        .onChange(of: navigationPath) { _, _ in isNavigationAtRoot = navigationPath.isEmpty }
        .onChange(of: isSidebarOpen) { _, newValue in if !newValue { navigationPath = NavigationPath() } }
        .background(AppTheme.Colors.background)
    }
}

enum SidebarRoute: Hashable {
    case babyProfile
    case language
}

struct SidebarIndexItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let route: SidebarRoute

    static var items: [SidebarIndexItem] {
        let service = LocalizationService.current

        return [
            SidebarIndexItem(
                id: "profile",
                title: L10n.text(
                    "shell.sidebar.profile.title",
                    service: service,
                    en: "Baby profile",
                    zh: "\u{5b9d}\u{5b9d}\u{8d44}\u{6599}"
                ),
                detail: L10n.text(
                    "shell.sidebar.profile.detail",
                    service: service,
                    en: "Core details that return across the timeline, like name and birthday.",
                    zh: "\u{4f1a}\u{56de}\u{5230}\u{65f6}\u{95f4}\u{7ebf}\u{91cc}\u{7684}\u{57fa}\u{7840}\u{4fe1}\u{606f}\uff0c\u6bd4\u5982\u540d\u5b57\u548c\u751f\u65e5\u3002"
                ),
                route: .babyProfile
            ),
            SidebarIndexItem(
                id: "language",
                title: L10n.text(
                    "shell.sidebar.language.title",
                    service: service,
                    en: "Language & Region",
                    zh: "\u{8bed}\u{8a00}\u4e0e\u5730\u533a"
                ),
                detail: L10n.text(
                    "shell.sidebar.language.detail",
                    service: service,
                    en: "Display language and timezone",
                    zh: "\u{663e}\u793a\u8bed\u8a00\u548c\u65f6\u533a"
                ),
                route: .language
            ),
        ]
    }
}
