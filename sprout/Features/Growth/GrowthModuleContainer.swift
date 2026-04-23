import Observation
import SwiftUI

struct GrowthModuleContainer: View {
    @Bindable var store: GrowthStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                GrowthZenToggle(
                    selectedMetric: store.viewState.currentMetric,
                    onSelect: { store.handle(.selectMetric($0)) }
                )

                GrowthMetaInfoAnchor(
                    metaInfo: store.viewState.metaInfo,
                    dataState: store.viewState.dataState
                )

                GrowthLifeLineChartCard(store: store)

                GrowthAIWhisperCard(
                    state: store.viewState.aiState,
                    content: store.viewState.aiContent,
                    onToggle: { store.handle(.toggleAIState) }
                )

                GrowthMilestoneTimeline(
                    milestones: store.viewState.milestones,
                    onAdd: { store.handle(.tapAddMilestone) },
                    onEdit: { store.handle(.tapEditMilestone($0)) }
                )

                GrowthSummaryCard(summary: store.viewState.growthSummary)
                Spacer(minLength: 140)
            }
            .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(AppTheme.Colors.background)
        .sheet(isPresented: sheetBinding) {
            GrowthRecordSheet(store: store)
                .presentationDetents([.height(520), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.Colors.background)
        }
        .sheet(isPresented: milestoneSheetBinding) {
            GrowthMilestoneEntrySheet(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.Colors.background)
        }
    }

    private var sheetBinding: Binding<Bool> {
        Binding(
            get: { store.viewState.sheetState.isPresented },
            set: { isPresented in
                if !isPresented {
                    store.handle(.dismissSheet)
                }
            }
        )
    }

    private var milestoneSheetBinding: Binding<Bool> {
        Binding(
            get: { store.viewState.milestoneSheetState.isPresented },
            set: { isPresented in
                if !isPresented {
                    store.handle(.dismissMilestoneSheet)
                }
            }
        )
    }
}
