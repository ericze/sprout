import SwiftUI

struct PaywallFeatureRow: View {
    let iconName: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 36, height: 36)
                .background(AppTheme.Colors.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Text(detail)
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }
}
