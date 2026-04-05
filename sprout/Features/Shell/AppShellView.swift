import Observation
import SwiftUI

struct AppShellView: View {
    private enum SidebarDragState {
        case revealing
        case dismissing
    }

    let babyRepository: BabyRepository
    @Bindable var store: HomeStore
    @Bindable var growthStore: GrowthStore
    @Bindable var treasureStore: TreasureStore
    @Bindable var activeBabyState: ActiveBabyState

    @State private var showSidebar = false
    @State private var isNavigationAtRoot = true
    @State private var selectedTab: HomeModule
    @State private var sidebarProgress: CGFloat = 0
    @State private var sidebarDragState: SidebarDragState?

    private let gesturePolicy = SidebarGesturePolicy()
    private let mainContentShiftFactor: CGFloat = 1
    private let sidebarAnimation = Animation.interactiveSpring(
        response: 0.28,
        dampingFraction: 0.86,
        blendDuration: 0.12
    )

    init(
        babyRepository: BabyRepository,
        store: HomeStore,
        growthStore: GrowthStore,
        treasureStore: TreasureStore,
        activeBabyState: ActiveBabyState,
        initialTab: HomeModule = .record
    ) {
        self.babyRepository = babyRepository
        self.store = store
        self.growthStore = growthStore
        self.treasureStore = treasureStore
        self.activeBabyState = activeBabyState
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        GeometryReader { proxy in
            let drawerWidth = min(max(proxy.size.width * 0.7, 280), 320)

            ZStack(alignment: .topLeading) {
                AppTheme.Colors.background
                    .ignoresSafeArea()

                mainContent(
                    drawerWidth: drawerWidth,
                    topInset: proxy.safeAreaInsets.top
                )

                if isSidebarVisible {
                    contentDismissOverlay(drawerWidth: drawerWidth)
                }

                sidebarOverlay(drawerWidth: drawerWidth)
            }
            .onChange(of: selectedTab) { _, _ in
                guard isSidebarVisible else { return }
                closeSidebar(drawerWidth: drawerWidth)
            }
        }
    }

    private var isContentDismissOverlayVisible: Bool {
        showSidebar || sidebarDragState == .dismissing
    }

    private var isSidebarVisible: Bool {
        showSidebar || sidebarProgress > 0.001 || sidebarDragState != nil
    }

    private var mainContentMaskOpacity: Double {
        0.16 * Double(sidebarProgress)
    }

    private var mainContentShadowOpacity: Double {
        0.08 * Double(sidebarProgress)
    }

    private func mainContent(drawerWidth: CGFloat, topInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            AppTheme.Colors.background

            VStack(spacing: 0) {
                MagazineTopBar(
                    selectedTab: selectedTab,
                    babyName: activeBabyState.headerConfig.babyName,
                    onSelect: selectTab,
                    onAvatarTap: { toggleSidebar(drawerWidth: drawerWidth) }
                )
                .padding(.bottom, 12)

                MainTabContentView(
                    store: store,
                    growthStore: growthStore,
                    treasureStore: treasureStore,
                    selectedTab: $selectedTab,
                    isSidebarPresented: showSidebar,
                    isSidebarInteracting: sidebarDragState != nil,
                    onRevealSidebarChanged: { translationWidth in
                        handleRevealDragChanged(
                            translationWidth: translationWidth,
                            drawerWidth: drawerWidth
                        )
                    },
                    onRevealSidebarEnded: { value in
                        handleRevealDragEnded(value, drawerWidth: drawerWidth)
                    }
                )
            }
            .padding(.top, topInset + 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .offset(x: mainContentOffset(drawerWidth: drawerWidth))
        .shadow(
            color: .black.opacity(mainContentShadowOpacity),
            radius: 18,
            x: 10,
            y: 0
        )
    }

    private func contentDismissOverlay(drawerWidth: CGFloat) -> some View {
        Color.black
            .opacity(mainContentMaskOpacity)
            .ignoresSafeArea()
            .padding(.leading, mainContentOffset(drawerWidth: drawerWidth))
            .contentShape(Rectangle())
            .allowsHitTesting(isContentDismissOverlayVisible)
            .onTapGesture {
                closeSidebar(drawerWidth: drawerWidth)
            }
            .gesture(dismissGesture(drawerWidth: drawerWidth))
    }

    private func sidebarOverlay(drawerWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            SidebarDrawer(
                headerConfig: activeBabyState.headerConfig,
                babyRepository: babyRepository,
                isNavigationAtRoot: $isNavigationAtRoot,
                isSidebarOpen: $showSidebar,
                onHeaderTap: {
                    AppHaptics.selection()
                }
            )
                .frame(width: drawerWidth, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .background(AppTheme.Colors.background)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 5)
                .offset(x: drawerOffset(drawerWidth: drawerWidth))
        }
        .opacity(isSidebarVisible ? 1 : 0)
        .allowsHitTesting(showSidebar)
    }

    private func dismissGesture(drawerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard isNavigationAtRoot else { return }
                guard showSidebar || sidebarDragState == .dismissing else { return }
                guard gesturePolicy.isPredominantlyHorizontal(value.translation) else { return }
                guard value.translation.width < 0 || sidebarDragState == .dismissing else { return }

                sidebarDragState = .dismissing
                sidebarProgress = gesturePolicy.dismissProgress(
                    translationWidth: value.translation.width,
                    drawerWidth: drawerWidth,
                    isSidebarPresented: showSidebar
                )
            }
            .onEnded { value in
                guard showSidebar || sidebarDragState == .dismissing else { return }

                let settleState = gesturePolicy.dismissSettleState(
                    translation: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation,
                    drawerWidth: drawerWidth,
                    isSidebarPresented: showSidebar
                )
                sidebarDragState = nil

                switch settleState {
                case .open:
                    withAnimation(sidebarAnimation) {
                        sidebarProgress = 1
                        showSidebar = true
                    }
                case .closed:
                    withAnimation(sidebarAnimation) {
                        sidebarProgress = 0
                        showSidebar = false
                    }
                }
            }
    }

    private func drawerOffset(drawerWidth: CGFloat) -> CGFloat {
        gesturePolicy.drawerOffset(
            drawerWidth: drawerWidth,
            progress: sidebarProgress
        )
    }

    private func mainContentOffset(drawerWidth: CGFloat) -> CGFloat {
        drawerWidth * mainContentShiftFactor * sidebarProgress
    }

    private func handleRevealDragChanged(translationWidth: CGFloat, drawerWidth: CGFloat) {
        let progress = gesturePolicy.revealProgress(
            translationWidth: translationWidth,
            drawerWidth: drawerWidth,
            isEligible: !showSidebar
        )

        guard progress > 0 || sidebarDragState == .revealing else { return }

        sidebarDragState = .revealing
        sidebarProgress = progress
    }

    private func handleRevealDragEnded(_ value: DragGesture.Value, drawerWidth: CGFloat) {
        guard sidebarDragState == .revealing || sidebarProgress > 0 else {
            return
        }

        let settleState = gesturePolicy.revealSettleState(
            translation: value.translation,
            predictedEndTranslation: value.predictedEndTranslation,
            drawerWidth: drawerWidth,
            isEligible: !showSidebar
        )
        sidebarDragState = nil

        switch settleState {
        case .open:
            guard !showSidebar else { return }
            AppHaptics.lightImpact()
            withAnimation(sidebarAnimation) {
                sidebarProgress = 1
                showSidebar = true
            }
        case .closed:
            withAnimation(sidebarAnimation) {
                sidebarProgress = 0
                showSidebar = false
            }
        }
    }

    private func selectTab(_ tab: HomeModule) {
        guard selectedTab != tab else { return }
        AppHaptics.selection()
        withAnimation(AppTheme.stateAnimation) {
            selectedTab = tab
        }
    }

    private func toggleSidebar(drawerWidth: CGFloat) {
        if showSidebar {
            closeSidebar(drawerWidth: drawerWidth)
        } else {
            openSidebar(drawerWidth: drawerWidth)
        }
    }

    private func openSidebar(drawerWidth _: CGFloat) {
        guard !showSidebar else {
            return
        }
        AppHaptics.lightImpact()
        sidebarDragState = nil
        withAnimation(sidebarAnimation) {
            sidebarProgress = 1
            showSidebar = true
        }
    }

    private func closeSidebar(drawerWidth _: CGFloat) {
        guard isSidebarVisible else {
            return
        }
        sidebarDragState = nil
        withAnimation(sidebarAnimation) {
            sidebarProgress = 0
            showSidebar = false
        }
    }
}
