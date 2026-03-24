import Observation
import SwiftUI

struct BottleLoggingTab: View {
    @Bindable var store: HomeStore

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 18) {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(FeedingDraftState.presets, id: \.self) { preset in
                    let isSelected = store.milkDraft.selectedBottlePreset == preset

                    Button {
                        store.handle(.selectBottlePreset(preset))
                    } label: {
                        Text("\(preset)ml")
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundStyle(isSelected ? Color.white : AppTheme.Colors.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(isSelected ? AppTheme.Colors.sageGreen : AppTheme.Colors.cardBackground)
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(AppTheme.Colors.divider, lineWidth: isSelected ? 0 : 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 16) {
                Text("不弹键盘，只做安静的微调")
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 22) {
                    bottleStepperButton(systemName: "minus", step: -1)

                    Text("\(store.milkDraft.bottleAmountMl)ml")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .frame(minWidth: 116)
                        .monospacedDigit()

                    bottleStepperButton(systemName: "plus", step: 1)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .shadow(color: AppTheme.Shadow.color, radius: AppTheme.Shadow.radius, y: AppTheme.Shadow.y)
        }
    }

    private func bottleStepperButton(systemName: String, step: Int) -> some View {
        Button {
            store.handle(.adjustBottleAmount(step))
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(width: 48, height: 48)
                .background(AppTheme.Colors.background)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
