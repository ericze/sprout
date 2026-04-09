import SwiftUI

struct FamilyGroupPlaceholderView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.section) {
            Spacer()

            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent)

            Text(L10n.text("paywall.coming_soon.title", en: "Coming Soon", zh: "即将上线"))
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(L10n.text("paywall.coming_soon.detail", en: "This feature is under development", zh: "功能开发中，敬请期待"))
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.screenHorizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .navigationTitle(L10n.text("paywall.feature.family.title", en: "Family Group", zh: "家庭组"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
