import Observation
import SwiftUI

struct HomeContainerView: View {
    @Bindable var store: HomeStore
    @Bindable var growthStore: GrowthStore
    @Bindable var treasureStore: TreasureStore
    @State private var isShowingSettings = false

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopModuleNavBar(
                    currentModule: store.routeState.currentModule,
                    onSelect: { module in
                        withAnimation(AppTheme.stateAnimation) {
                            store.handle(.selectModule(module))
                        }
                    },
                    onSettings: {
                        AppHaptics.lightImpact()
                        isShowingSettings = true
                    }
                )
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(AppTheme.Colors.background.opacity(0.96))

                TabView(selection: moduleBinding) {
                    RecordHomeScrollView(store: store)
                        .tag(HomeModule.record)

                    GrowthModuleContainer(store: growthStore)
                    .tag(HomeModule.growth)

                    TreasureModuleContainer(store: treasureStore)
                        .tag(HomeModule.collection)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.routeState.currentModule == .record {
                VStack(spacing: AppTheme.Spacing.floatingGap) {
                    if let ongoingSleep = store.viewState.ongoingSleep {
                        OngoingStateBar(
                            session: ongoingSleep,
                            onTap: { store.handle(.tapOngoingSleep) },
                            onEnd: { store.handle(.finishSleep) }
                        )
                        .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
                    }

                    FloatingActionBar(
                        hasOngoingSleep: store.viewState.ongoingSleep != nil,
                        onMilkTapped: { store.handle(.tapMilkEntry) },
                        onFoodTapped: { store.handle(.tapFoodEntry) },
                        onDiaperTapped: { store.handle(.tapDiaperEntry) },
                        onStartSleep: { store.handle(.tapSleepEntry) },
                        onEndSleep: { store.handle(.finishSleep) }
                    )
                }
                .padding(.top, 8)
                .padding(.bottom, AppTheme.Spacing.floatingBottom)
                .background(Color.clear)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = activeUndoToast {
                UndoToast(
                    state: toast,
                    onUndo: performUndo,
                    onDismiss: dismissUndo
                )
                .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
                .padding(.bottom, store.routeState.currentModule == .record ? 134 : 36)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(AppTheme.stateAnimation, value: activeUndoToast)
        .sheet(item: activeSheetBinding) { sheet in
            sheetView(for: sheet)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsPlaceholderView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.Colors.background)
        }
    }

    private var moduleBinding: Binding<HomeModule> {
        Binding(
            get: { store.routeState.currentModule },
            set: { store.handle(.selectModule($0)) }
        )
    }

    private var activeSheetBinding: Binding<ActiveSheet?> {
        Binding(
            get: { store.routeState.activeSheet },
            set: { newValue in
                if newValue == nil {
                    store.handle(.dismissSheet)
                } else {
                    store.routeState.activeSheet = newValue
                }
            }
        )
    }

    private var activeUndoToast: UndoToastState? {
        switch store.routeState.currentModule {
        case .record:
            store.viewState.undoToast
        case .growth:
            growthStore.viewState.undoToast
        case .collection:
            treasureStore.viewState.undoToast
        }
    }

    private func performUndo() {
        switch store.routeState.currentModule {
        case .record:
            store.handle(.undoLastRecord)
        case .growth:
            growthStore.handle(.undoLastRecord)
        case .collection:
            treasureStore.handle(.undoLastEntry)
        }
    }

    private func dismissUndo() {
        switch store.routeState.currentModule {
        case .record:
            store.handle(.dismissUndo)
        case .growth:
            growthStore.handle(.dismissUndo)
        case .collection:
            treasureStore.handle(.dismissUndo)
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .milk:
            MilkLoggingSheet(store: store)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.Colors.background)
        case .diaper:
            DiaperRecordSheet(store: store)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.Colors.background)
        case .food:
            FoodRecordSheet(store: store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(store.shouldDisableFoodInteractiveDismiss)
                .presentationBackground(AppTheme.Colors.background)
        case .sleepControl:
            SleepControlSheet(store: store)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.Colors.background)
        }
    }
}

private struct SettingsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BaseRecordSheet(title: "设置", onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: 14) {
                Text("设置页暂时保留占位。")
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Text("本轮先把首页记录闭环做稳，设置能力后续单独展开。")
                    .font(AppTheme.Typography.sheetBody)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
