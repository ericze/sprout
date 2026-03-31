import SwiftUI

struct SidebarDrawer: View {
    let headerConfig: HomeHeaderConfig
    let onHeaderTap: () -> Void
    let onIndexItemTap: (SidebarIndexItem) -> Void

    private let calendar = Calendar.current

    init(
        headerConfig: HomeHeaderConfig,
        onHeaderTap: @escaping () -> Void = {},
        onIndexItemTap: @escaping (SidebarIndexItem) -> Void = { _ in }
    ) {
        self.headerConfig = headerConfig
        self.onHeaderTap = onHeaderTap
        self.onIndexItemTap = onIndexItemTap
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                headerCard
                indexCard
                footerNote
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.Colors.background)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {})
    }

    private var headerCard: some View {
        Button(action: onHeaderTap) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    Text(monogram)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .frame(width: 56, height: 56)
                        .background(AppTheme.Colors.cardBackground)
                        .overlay {
                            Circle()
                                .stroke(AppTheme.Colors.divider, lineWidth: 1)
                        }
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 6) {
                        Text(headerConfig.babyName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primaryText)

                        Text(sidebarAgeText)
                            .font(AppTheme.Typography.meta)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    sidebarMetaRow(title: String(localized: "shell.sidebar.birth_date"), value: birthDateText)
                    sidebarMetaRow(title: String(localized: "shell.sidebar.note.title"), value: String(localized: "shell.sidebar.note.body"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .shadow(color: AppTheme.Shadow.color, radius: AppTheme.Shadow.radius, y: AppTheme.Shadow.y)
    }

    private var indexCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "shell.sidebar.index.title"))
                .font(.system(size: 12, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .padding(.bottom, 12)

            ForEach(SidebarIndexItem.items) { item in
                Button(action: {
                    onIndexItemTap(item)
                }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundStyle(AppTheme.Colors.primaryText)

                        Text(item.detail)
                            .font(AppTheme.Typography.cardBody)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if item.id != SidebarIndexItem.items.last?.id {
                    Divider()
                        .overlay(AppTheme.Colors.divider)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .shadow(color: AppTheme.Shadow.color, radius: AppTheme.Shadow.radius, y: AppTheme.Shadow.y)
    }

    private var footerNote: some View {
        Text(String(localized: "shell.sidebar.footer"))
            .font(AppTheme.Typography.meta)
            .foregroundStyle(AppTheme.Colors.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func sidebarMetaRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.Colors.tertiaryText)

            Text(value)
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var monogram: String {
        let trimmedName = headerConfig.babyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackCharacter = HomeHeaderConfig.placeholder.babyName.first ?? Character("B")
        return String(trimmedName.first ?? fallbackCharacter)
    }

    private var ageInDays: Int {
        let start = calendar.startOfDay(for: headerConfig.birthDate)
        let end = calendar.startOfDay(for: .now)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days + 1, 1)
    }

    private var birthDateText: String {
        headerConfig.birthDate.formatted(
            .dateTime
                .year()
                .month(.wide)
                .day()
        )
    }

    private var sidebarAgeText: String {
        "\(String(localized: "shell.sidebar.age.prefix"))\(ageInDays.formatted())\(String(localized: "shell.sidebar.age.suffix"))"
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
    let isPro: Bool
    let route: SidebarRoute?

    static let items: [SidebarIndexItem] = [
        SidebarIndexItem(
            id: "profile",
            title: String(localized: "shell.sidebar.profile.title"),
            detail: String(localized: "shell.sidebar.profile.detail"),
            isPro: false,
            route: .babyProfile
        ),
        SidebarIndexItem(
            id: "preferences",
            title: String(localized: "shell.sidebar.preferences.title"),
            detail: String(localized: "shell.sidebar.preferences.detail"),
            isPro: false,
            route: .language
        ),
        SidebarIndexItem(
            id: "family",
            title: String(localized: "shell.sidebar.family.title"),
            detail: String(localized: "shell.sidebar.family.detail"),
            isPro: true,
            route: nil
        ),
        SidebarIndexItem(
            id: "cloud",
            title: String(localized: "shell.sidebar.cloud.title"),
            detail: String(localized: "shell.sidebar.cloud.detail"),
            isPro: true,
            route: nil
        ),
    ]
}
