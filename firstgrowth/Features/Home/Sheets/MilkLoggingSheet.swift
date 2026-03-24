import Observation
import SwiftUI

struct MilkLoggingSheet: View {
    @Bindable var store: HomeStore

    var body: some View {
        BaseRecordSheet(title: "喂奶", onClose: { store.handle(.dismissSheet) }) {
            VStack(spacing: 24) {
                MilkTabSwitcher(selectedTab: store.milkDraft.selectedTab) { tab in
                    store.handle(.selectMilkTab(tab))
                }

                switch store.milkDraft.selectedTab {
                case .nursing:
                    NursingTimerTab(store: store)
                case .bottle:
                    BottleLoggingTab(store: store)
                }
            }
        } footer: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let isEnabled = store.milkDraft.canSubmit(now: context.date)

                Button {
                    store.handle(.saveFeedingRecord)
                } label: {
                    Text(store.milkDraft.submitButtonTitle(now: context.date))
                        .font(AppTheme.Typography.primaryButton)
                        .foregroundStyle(isEnabled ? Color.white : AppTheme.Colors.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            isEnabled
                                ? AppTheme.Colors.primaryText
                                : AppTheme.Colors.primaryText.opacity(0.14)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
            }
        }
    }
}
