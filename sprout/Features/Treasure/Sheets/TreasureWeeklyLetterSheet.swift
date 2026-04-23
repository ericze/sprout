import SwiftUI

struct TreasureWeeklyLetterSheet: View {
    let item: TreasureTimelineItem
    let onClose: () -> Void
    let onRegenerate: () -> Void
    private let localizationService = LocalizationService.current

    var body: some View {
        BaseRecordSheet(title: L10n.text("treasure.weekly_letter.title", en: "Weekly letter", zh: "时光信笺"), onClose: onClose) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let weekStart = item.weekStart, let weekEnd = item.weekEnd {
                        Text(rangeText(weekStart: weekStart, weekEnd: weekEnd))
                            .font(AppTheme.Typography.meta)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    Text(item.expandedText ?? item.collapsedText ?? "")
                        .font(AppTheme.Typography.sheetBody)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
            }
        } footer: {
            Button(action: onRegenerate) {
                Text(L10n.text("treasure.letter.regenerate", en: "Regenerate", zh: "重新生成"))
                    .font(AppTheme.Typography.primaryButton)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppTheme.Colors.primaryText.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func rangeText(weekStart: Date, weekEnd: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localizationService.locale
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return L10n.format(
            "treasure.weekly_letter.range",
            service: localizationService,
            locale: localizationService.locale,
            en: "%@ - %@",
            zh: "%@ - %@",
            arguments: [formatter.string(from: weekStart), formatter.string(from: weekEnd)]
        )
    }
}
