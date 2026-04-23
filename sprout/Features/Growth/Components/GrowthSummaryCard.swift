import SwiftUI

struct GrowthSummaryCard: View {
    let summary: GrowthSummary
    private let textRenderer = GrowthTextRenderer()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("growth.summary.title", en: "Growth Summary", zh: "成长概览"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Colors.secondaryText)

            Text(bodyText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let milestoneText = milestoneText {
                Text(milestoneText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .shadow(color: AppTheme.Shadow.color, radius: AppTheme.Shadow.radius, y: AppTheme.Shadow.y)
    }

    private var bodyText: String {
        switch summary.kind {
        case .guidance:
            return L10n.format(
                "growth.summary.guidance_format",
                service: textRenderer.localizationService,
                en: "Start tracking your baby's %@",
                zh: "开始记录宝宝的%@数据",
                arguments: [textRenderer.metricTitle(summary.metric)]
            )
        case .started:
            let valueText: String
            if let value = summary.latestValue {
                valueText = textRenderer.valueText(value, metric: summary.metric)
            } else {
                valueText = "-"
            }
            return L10n.format(
                "growth.summary.started_format",
                service: textRenderer.localizationService,
                en: "Recorded %@",
                zh: "已记录 %@",
                arguments: [valueText]
            )
        case let .summary(delta, daysSinceLast, _):
            let deltaText = textRenderer.valueText(abs(delta), metric: summary.metric)
            let sign = delta >= 0 ? "+" : "-"
            return L10n.format(
                "growth.summary.summary_format",
                service: textRenderer.localizationService,
                en: "Last record %@ days ago, changed %@%@",
                zh: "上次记录 %@ 天前，变化 %@%@",
                arguments: [
                    String(daysSinceLast),
                    sign,
                    deltaText
                ]
            )
        }
    }

    private var milestoneText: String? {
        guard case let .summary(_, _, milestoneCount) = summary.kind, milestoneCount > 0 else {
            return nil
        }
        return L10n.format(
            "growth.summary.milestones_format",
            service: textRenderer.localizationService,
            en: "%@ milestones this month",
            zh: "本月 %@ 个里程碑",
            arguments: [String(milestoneCount)]
        )
    }
}
