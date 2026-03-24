import SwiftUI

struct TreasureFloatingAddButton: View {
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 11, weight: .medium))

                Text("留住今天")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(TreasureTheme.floatingButtonForeground)
            .padding(.horizontal, TreasureTheme.floatingButtonHorizontalPadding)
            .padding(.vertical, TreasureTheme.floatingButtonVerticalPadding)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            }
            .shadow(
                color: TreasureTheme.floatingButtonShadowColor,
                radius: TreasureTheme.floatingButtonShadowRadius,
                y: TreasureTheme.floatingButtonShadowY
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("留住今天")
        .offset(y: isVisible ? 0 : 100)
        .opacity(isVisible ? 1 : 0)
    }
}
