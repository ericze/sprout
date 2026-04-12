import Foundation
import SwiftUI

struct SidebarMenuView: View {
    let headerConfig: HomeHeaderConfig
    let onNavigate: (SidebarRoute) -> Void

    private let calendar = Calendar.current
    private let localizationService = LocalizationService.current

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
        Button(action: {
            AppHaptics.selection()
            onNavigate(.babyProfile)
        }) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    BabyAvatarView(
                        avatarPath: headerConfig.avatarPath,
                        monogram: monogram,
                        size: 56
                    )

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
                    sidebarMetaRow(
                        title: localizationService.string(
                            forKey: "shell.sidebar.birth_date",
                            fallback: "Birth date"
                        ),
                        value: birthDateText
                    )
                    sidebarMetaRow(
                        title: localizationService.string(
                            forKey: "shell.sidebar.note.title",
                            fallback: "A note"
                        ),
                        value: L10n.text(
                            "shell.sidebar.note.body.quiet",
                            service: localizationService,
                            en: "A quiet place for profile, account, sync, and preferences.",
                            zh: "这是一个安静的角落，用来放宝宝资料、账号、同步和偏好设置。"
                        )
                    )
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
        let items = SidebarIndexItem.items

        return VStack(alignment: .leading, spacing: 0) {
            Text(
                localizationService.string(
                    forKey: "shell.sidebar.index.title",
                    fallback: "Settings"
                )
            )
            .font(.system(size: 12, weight: .medium))
            .tracking(0.6)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding(.bottom, 12)

            ForEach(items) { item in
                Button(action: {
                    AppHaptics.selection()
                    onNavigate(item.route)
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(AppTheme.Typography.cardTitle)
                                .foregroundStyle(AppTheme.Colors.primaryText)

                            Text(item.detail)
                                .font(AppTheme.Typography.cardBody)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        if item.isPro {
                            ProBadgeView(showLock: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if item.id != items.last?.id {
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
        Text(
            L10n.text(
                "shell.sidebar.footer.quiet",
                service: localizationService,
                en: "A quiet entry for account, sync, and settings, without interrupting the calm of the record page.",
                zh: "把账号、同步和设置留在这里，不打断记录页原本的安静。"
            )
        )
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
        let formatter = DateFormatter()
        formatter.locale = localizationService.locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMMd")
        return formatter.string(from: headerConfig.birthDate)
    }

    private var sidebarAgeText: String {
        let prefix = localizationService.string(
            forKey: "shell.sidebar.age.prefix",
            fallback: "Day "
        )
        let suffix = localizationService.string(
            forKey: "shell.sidebar.age.suffix",
            fallback: ""
        )
        return "\(prefix)\(ageInDays)\(suffix)"
    }
}
