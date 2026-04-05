import Foundation
import SwiftUI

struct SidebarMenuView: View {
    let headerConfig: HomeHeaderConfig
    let onHeaderTap: () -> Void
    let onNavigate: (SidebarRoute) -> Void

    private let calendar = Calendar.current

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
                    sidebarMetaRow(
                        title: L10n.text(
                            "shell.sidebar.birth_date",
                            en: "Birth date",
                            zh: "\u{51fa}\u{751f}\u65e5\u671f"
                        ),
                        value: birthDateText
                    )
                    sidebarMetaRow(
                        title: L10n.text(
                            "shell.sidebar.note.title",
                            en: "A note",
                            zh: "\u{4e00}\u6761\u8bb0\u4e0b\u6765\u7684\u8bdd"
                        ),
                        value: L10n.text(
                            "shell.sidebar.note.body",
                            en: "A quiet place for settings, profile, and preferences.",
                            zh: "\u{5b89}\u9759\u6536\u7eb3\u8bbe\u7f6e\u3001\u8d44\u6599\u548c\u504f\u597d\u3002"
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

        VStack(alignment: .leading, spacing: 0) {
            Text(
                L10n.text(
                    "shell.sidebar.index.title",
                    en: "Settings",
                    zh: "\u{8bbe}\u7f6e"
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
                "shell.sidebar.footer",
                en: "A quiet entry for settings, without interrupting the calm of the record page.",
                zh: "\u{5b89}\u9759\u5730\u6536\u8d77\u8bbe\u7f6e\uff0c\u4e0d\u6253\u65ad\u8bb0\u5f55\u9875\u7684\u5e73\u9759\u3002"
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
        formatter.locale = LocalizationService.current.locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMMd")
        return formatter.string(from: headerConfig.birthDate)
    }

    private var sidebarAgeText: String {
        let prefix = L10n.text("shell.sidebar.age.prefix", en: "Day ", zh: "\u{7b2c}")
        let suffix = L10n.text("shell.sidebar.age.suffix", en: "", zh: "\u{5929}")
        return "\(prefix)\(ageInDays)\(suffix)"
    }
}
