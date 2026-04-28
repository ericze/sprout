import SwiftUI

struct GrowthAIWhisperCard: View {
    let state: GrowthAIState
    let content: GrowthAIContent
    let onToggle: () -> Void
    private let textRenderer = GrowthTextRenderer()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text(L10n.text("growth.ai.title", en: "Growth Insight", zh: "成长解读"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Spacer()

                Button(action: onToggle) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .rotationEffect(state == .expanded ? .degrees(0) : .degrees(-90))
                        .frame(width: 32, height: 32)
                        .background(AppTheme.Colors.background.opacity(0.55))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    state == .expanded
                        ? L10n.text("growth.ai.collapse", en: "Collapse note", zh: "折叠解读")
                        : L10n.text("growth.ai.expand", en: "Expand note", zh: "展开解读")
                )
            }

            Text(bodyText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .shadow(color: AppTheme.Shadow.color, radius: AppTheme.Shadow.radius, y: AppTheme.Shadow.y)
    }

    private var bodyText: String {
        state == .expanded
            ? textRenderer.aiText(content.expanded)
            : textRenderer.aiCollapsedText(content.collapsed)
    }
}
