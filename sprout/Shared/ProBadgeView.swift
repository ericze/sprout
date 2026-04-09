import SwiftUI

/// Displays a "Pro" badge or lock icon for Pro-gated features.
struct ProBadgeView: View {
    let showLock: Bool

    init(showLock: Bool = true) {
        self.showLock = showLock
    }

    var body: some View {
        if showLock {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.Colors.secondaryText)
        } else {
            Text(L10n.text("sidebar.pro.badge", en: "Pro", zh: "Pro"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.Colors.accent)
                .clipShape(Capsule())
        }
    }
}
