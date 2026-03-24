import Observation
import SwiftUI

struct NursingTimerTab: View {
    @Bindable var store: HomeStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    NursingTimerBlock(
                        side: .left,
                        displayedSeconds: store.milkDraft.displayedSeconds(for: .left, now: context.date),
                        isActive: store.milkDraft.activeSide == .left
                    ) {
                        store.handle(.tapNursingSide(.left))
                    }

                    NursingTimerBlock(
                        side: .right,
                        displayedSeconds: store.milkDraft.displayedSeconds(for: .right, now: context.date),
                        isActive: store.milkDraft.activeSide == .right
                    ) {
                        store.handle(.tapNursingSide(.right))
                    }
                }

                Text("轻触当前侧暂停，切换另一侧会自动结算上一侧")
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct NursingTimerBlock: View {
    let side: NursingSide
    let displayedSeconds: Int
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Text(side.title)
                        .font(.system(size: 20, weight: .semibold))

                    Text(side.badge)
                        .font(.system(size: 15, weight: .medium))
                        .opacity(0.7)
                }

                Spacer(minLength: 0)

                Text(formattedDuration)
                    .font(.system(size: 36, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isActive ? Color.white : AppTheme.Colors.primaryText)
            .frame(maxWidth: .infinity, minHeight: 208, alignment: .leading)
            .padding(22)
            .background(isActive ? AppTheme.Colors.sageGreen : AppTheme.Colors.background)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .stroke(AppTheme.Colors.divider, lineWidth: isActive ? 0 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var formattedDuration: String {
        let minutes = max(displayedSeconds, 0) / 60
        let seconds = max(displayedSeconds, 0) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
