import SwiftUI

struct SidebarDrawer: View {
    let headerConfig: HomeHeaderConfig
    let babyRepository: BabyRepository
    let onShowPaywall: () -> Void
    @Binding var isNavigationAtRoot: Bool
    @Binding var isSidebarOpen: Bool
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            SidebarMenuView(
                headerConfig: headerConfig,
                onNavigate: { route in
                    let item = SidebarIndexItem.items.first { $0.route == route }
                    if let item, item.isPro {
                        if subscriptionManager.isPro {
                            navigationPath.append(route)
                        } else {
                            onShowPaywall()
                        }
                    } else {
                        navigationPath.append(route)
                    }
                }
            )
            .navigationDestination(for: SidebarRoute.self) { route in
                switch route {
                case .babyProfile:
                    BabyProfileView(babyRepository: babyRepository)
                case .language:
                    LanguageRegionView(onLanguageChange: { newLanguage in
                        AppLanguageManager.shared.language = newLanguage
                    })
                case .account:
                    AccountView()
                case .cloudSync:
                    CloudSyncView(onOpenAccount: {
                        navigationPath.append(SidebarRoute.account)
                    })
                case .familyGroup:
                    FamilyGroupPlaceholderView()
                }
            }
        }
        .onChange(of: navigationPath) { _, _ in isNavigationAtRoot = navigationPath.isEmpty }
        .onChange(of: isSidebarOpen) { _, newValue in
            if !newValue {
                navigationPath = NavigationPath()
            }
        }
        .background(AppTheme.Colors.background)
    }
}

enum SidebarRoute: Hashable {
    case babyProfile
    case language
    case account
    case cloudSync
    case familyGroup
}

struct SidebarIndexItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let route: SidebarRoute
    let isPro: Bool

    static var items: [SidebarIndexItem] {
        let service = LocalizationService.current

        return [
            SidebarIndexItem(
                id: "language",
                title: service.string(
                    forKey: "shell.sidebar.language.title",
                    fallback: "Language & Region"
                ),
                detail: service.string(
                    forKey: "shell.sidebar.language.detail",
                    fallback: "Display language and timezone"
                ),
                route: .language,
                isPro: false
            ),
            SidebarIndexItem(
                id: "account",
                title: L10n.text(
                    "shell.sidebar.account.title",
                    service: service,
                    en: "Account",
                    zh: "账号"
                ),
                detail: L10n.text(
                    "shell.sidebar.account.detail",
                    service: service,
                    en: "Sign in and manage this device connection",
                    zh: "登录并管理这台设备的连接"
                ),
                route: .account,
                isPro: false
            ),
            SidebarIndexItem(
                id: "cloudSync",
                title: L10n.text(
                    "shell.sidebar.cloud.title",
                    service: service,
                    en: "Cloud Sync",
                    zh: "云端同步"
                ),
                detail: L10n.text(
                    "shell.sidebar.cloud.detail",
                    service: service,
                    en: "Back up records when you are signed in",
                    zh: "登录后再安静地备份记录"
                ),
                route: .cloudSync,
                isPro: false
            ),
            SidebarIndexItem(
                id: "familyGroup",
                title: service.string(
                    forKey: "shell.sidebar.family.title",
                    fallback: "Family Group"
                ),
                detail: service.string(
                    forKey: "shell.sidebar.family.detail",
                    fallback: "Invite family to share records"
                ),
                route: .familyGroup,
                isPro: true
            ),
        ]
    }
}
