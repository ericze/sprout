import SwiftUI

struct TopModuleNavBar: View {
    let currentModule: HomeModule
    let onSelect: (HomeModule) -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 22) {
                ForEach(HomeModule.allCases) { module in
                    Button {
                        onSelect(module)
                    } label: {
                        VStack(spacing: 5) {
                            Text(module.title)
                                .font(module == currentModule ? AppTheme.Typography.navSelected : AppTheme.Typography.nav)
                                .foregroundStyle(module == currentModule ? AppTheme.Colors.primaryText : AppTheme.Colors.secondaryText)

                            Capsule()
                                .fill(module == currentModule ? AppTheme.Colors.sageGreen : .clear)
                                .frame(width: 16, height: 3)
                        }
                        .frame(minWidth: 48)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.Colors.cardBackground.opacity(0.7))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开设置")
        }
        .padding(.horizontal, AppTheme.Spacing.navigationHorizontal)
    }
}
