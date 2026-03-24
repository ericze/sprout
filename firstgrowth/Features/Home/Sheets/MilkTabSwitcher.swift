import SwiftUI

struct MilkTabSwitcher: View {
    let selectedTab: MilkTab
    let onSelect: (MilkTab) -> Void

    var body: some View {
        HStack(spacing: 22) {
            ForEach(MilkTab.allCases) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    Text(tab.title)
                        .font(tab == selectedTab ? AppTheme.Typography.navSelected : AppTheme.Typography.nav)
                        .foregroundStyle(
                            tab == selectedTab
                                ? AppTheme.Colors.primaryText
                                : AppTheme.Colors.primaryText.opacity(0.4)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
