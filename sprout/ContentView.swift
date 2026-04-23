import os
import SwiftData
import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeBabyState = ActiveBabyState()
    @State private var store: HomeStore? = nil
    @State private var growthStore: GrowthStore? = nil
    @State private var treasureStore: TreasureStore? = nil
    @State private var babyRepository: BabyRepository? = nil
    @State private var authManager: AuthManager? = nil
    @State private var syncEngine: SyncEngine? = nil
    @State private var cloudSyncStatusStore = CloudSyncStatusStore()
    @State private var hasBootstrapped = false
    @State private var subscriptionManager = SubscriptionManager()
    private let launchOverrides = AppLaunchOverrides.current

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            if let store, let growthStore, let treasureStore, let babyRepository, let authManager {
                AppShellView(
                    babyRepository: babyRepository,
                    store: store,
                    growthStore: growthStore,
                    treasureStore: treasureStore,
                    activeBabyState: activeBabyState,
                    initialTab: launchOverrides.initialModule ?? .record
                )
                    .environment(authManager)
                    .environment(cloudSyncStatusStore)
                    .environment(subscriptionManager)
            }
        }
        .onChange(of: activeBabyState.headerConfig) { _, newConfig in
            store?.updateHeaderConfig(newConfig)
            growthStore?.updateHeaderConfig(newConfig)
            growthStore?.refreshAfterProfileChange()
            treasureStore?.updateHeaderConfig(newConfig)
        }
        .task {
            guard !hasBootstrapped else { return }
            hasBootstrapped = true

            await subscriptionManager.loadProducts()
            subscriptionManager.startListening()
            await subscriptionManager.refreshStatus()

            let repo = BabyRepository(modelContext: modelContext, activeBabyState: activeBabyState)
            repo.createDefaultIfNeeded()

            if authManager == nil {
                let supabaseService: any SupabaseServicing

                do {
                    supabaseService = try SupabaseService.make()
                } catch {
                    AppLogger.startup.error("Supabase setup failed: \(String(describing: error), privacy: .public)")
                    supabaseService = BootstrapFallbackSupabaseService()
                }

                let engine = SyncEngine(
                    modelContext: modelContext,
                    supabaseService: supabaseService,
                    currentUserIDProvider: { authManager?.currentUser?.id },
                    onMemoryPulled: { [modelContext] weekStart in
                        let treasureRepo = TreasureRepository(modelContext: modelContext)
                        let composer = WeeklyLetterComposer()
                        do {
                            try treasureRepo.syncWeeklyLetter(
                                for: weekStart,
                                composer: composer,
                                generatedAt: Date()
                            )
                        } catch {
                            AppLogger.startup.error(
                                "Weekly letter recompute failed: \(String(describing: error), privacy: .public)"
                            )
                        }
                    }
                )
                syncEngine = engine
                cloudSyncStatusStore.configure(syncEngine: engine)

                let manager = AuthManager(
                    supabaseService: supabaseService,
                    runLocalBootstrapper: {
                        _ = LocalSyncBootstrapper(modelContext: modelContext)
                            .prepareForSync(activeBabyState: activeBabyState)
                    },
                    triggerSyncHook: { reason in
                        AppLogger.startup.info(
                            "Auth hook requested sync: \(reason.rawValue, privacy: .public)"
                        )
                        guard let authManager else { return }
                        Task {
                            await cloudSyncStatusStore.syncIfEligible(
                                authState: authManager.authState,
                                reason: reason
                            )
                        }
                    }
                )
                authManager = manager
                await manager.restoreSession()
                cloudSyncStatusStore.refreshFromEngine()
            }

            let headerConfig = HomeHeaderConfig.from(repo.activeBaby)
            activeBabyState.headerConfig = headerConfig
            launchOverrides.applyIfNeeded(modelContext: modelContext, headerConfig: headerConfig)

            let homeStore = HomeStore(headerConfig: headerConfig)
            let growth = GrowthStore(headerConfig: headerConfig)
            let treasure = TreasureStore(headerConfig: headerConfig)

            homeStore.configure(modelContext: modelContext)
            homeStore.configure(aiService: MockFoodAIAssistService())
            growth.configure(modelContext: modelContext)
            treasure.configure(modelContext: modelContext)

            growth.onMilestoneChanged = { weekStart in
                treasure.recomputeWeeklyLetter(forWeekStart: weekStart)
            }

            homeStore.onAppear()
            growth.onAppear()
            treasure.onAppear()

            if let initialGrowthMetric = launchOverrides.initialGrowthMetric {
                growth.handle(.selectMetric(initialGrowthMetric))
            }

            if launchOverrides.opensGrowthEntry {
                growth.handle(.tapEntry)
                if launchOverrides.growthEntryMode == .manual {
                    growth.handle(.switchToManualInput)
                }
            }

            store = homeStore
            growthStore = growth
            treasureStore = treasure
            babyRepository = repo
        }
    }
}

private struct BootstrapFallbackSupabaseService: SupabaseServicing {
    func restoreSession() async throws -> SupabaseSession? { nil }
    func signIn(email: String, password: String) async throws -> SupabaseSession { throw SupabaseServiceError.sdkUnavailable }
    func signUp(email: String, password: String) async throws -> SupabaseSession { throw SupabaseServiceError.sdkUnavailable }
    func signOut() async throws {}
    func fetchServerNow() async throws -> Date { throw SupabaseServiceError.sdkUnavailable }
    func upsertBabyProfile(_ profile: BabyProfileDTO, expectedVersion: Int64?) async throws -> BabyProfileDTO { profile }
    func upsertRecordItem(_ record: RecordItemDTO, expectedVersion: Int64?) async throws -> RecordItemDTO { record }
    func upsertMemoryEntry(_ entry: MemoryEntryDTO, expectedVersion: Int64?) async throws -> MemoryEntryDTO { entry }
    func fetchBabyProfiles(updatedAfter: Date?, upTo upperBound: Date) async throws -> [BabyProfileDTO] { [] }
    func fetchRecordItems(updatedAfter: Date?, upTo upperBound: Date) async throws -> [RecordItemDTO] { [] }
    func fetchMemoryEntries(updatedAfter: Date?, upTo upperBound: Date) async throws -> [MemoryEntryDTO] { [] }
    func softDelete(table: SupabaseTable, id: UUID, expectedVersion: Int64?) async throws {}
    func uploadAsset(data: Data, bucket: StorageBucket, path: String, contentType: String) async throws {}
    func downloadAsset(bucket: StorageBucket, path: String) async throws -> Data { Data() }
    func deleteAsset(bucket: StorageBucket, path: String) async throws {}
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer.make())
}

private struct AppLaunchOverrides {
    static let current = AppLaunchOverrides()

    let initialModule: HomeModule?
    let initialGrowthMetric: GrowthMetric?
    let growthSeedPreset: GrowthSeedPreset?
    let treasureSeedPreset: TreasureSeedPreset?
    let opensGrowthEntry: Bool
    let growthEntryMode: GrowthEntryLaunchMode

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        initialModule = environment["SPROUT_INITIAL_MODULE"].flatMap(HomeModule.init(rawValue:))
        initialGrowthMetric = environment["SPROUT_GROWTH_METRIC"].flatMap(GrowthMetric.init(rawValue:))
        growthSeedPreset = environment["SPROUT_GROWTH_SEED"].flatMap(GrowthSeedPreset.init(rawValue:))
        treasureSeedPreset = environment["SPROUT_TREASURE_SEED"].flatMap(TreasureSeedPreset.init(rawValue:))
        opensGrowthEntry = environment["SPROUT_GROWTH_OPEN_ENTRY"] == "1"
        growthEntryMode = environment["SPROUT_GROWTH_ENTRY_MODE"].flatMap(GrowthEntryLaunchMode.init(rawValue:)) ?? .ruler
    }

    @MainActor
    func applyIfNeeded(modelContext: ModelContext, headerConfig: HomeHeaderConfig) {
        do {
            if let growthSeedPreset {
                try clearGrowthRecords(from: modelContext)
                try insertGrowthRecords(for: growthSeedPreset, into: modelContext, headerConfig: headerConfig)
            }

            if let treasureSeedPreset {
                try clearTreasureContent(from: modelContext)
                try insertTreasureContent(for: treasureSeedPreset, into: modelContext, headerConfig: headerConfig)
            }

            if growthSeedPreset != nil || treasureSeedPreset != nil {
                try modelContext.save()
            }
        } catch {
            assertionFailure("Failed to apply launch overrides: \(error)")
        }
    }

    @MainActor
    private func clearGrowthRecords(from modelContext: ModelContext) throws {
        let heightType = RecordType.height.rawValue
        let weightType = RecordType.weight.rawValue
        let headCircumferenceType = RecordType.headCircumference.rawValue
        let descriptor = FetchDescriptor<RecordItem>(
            predicate: #Predicate<RecordItem> { item in
                item.type == heightType || item.type == weightType || item.type == headCircumferenceType
            }
        )
        let existingRecords = try modelContext.fetch(descriptor)
        existingRecords.forEach(modelContext.delete)
    }

    @MainActor
    private func clearTreasureContent(from modelContext: ModelContext) throws {
        try modelContext.fetch(FetchDescriptor<MemoryEntry>()).forEach(modelContext.delete)
        try modelContext.fetch(FetchDescriptor<WeeklyLetter>()).forEach(modelContext.delete)
    }

    @MainActor
    private func insertGrowthRecords(
        for preset: GrowthSeedPreset,
        into modelContext: ModelContext,
        headerConfig: HomeHeaderConfig
    ) throws {
        let records = preset.makeRecords(headerConfig: headerConfig)
        records.forEach(modelContext.insert)
    }

    @MainActor
    private func insertTreasureContent(
        for preset: TreasureSeedPreset,
        into modelContext: ModelContext,
        headerConfig: HomeHeaderConfig
    ) throws {
        let calendar = AppLaunchOverrides.treasureCalendar
        let entries = preset.makeEntries(headerConfig: headerConfig, calendar: calendar)
        entries.forEach(modelContext.insert)

        let groupedEntries = Dictionary(grouping: entries) { entry in
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: entry.createdAt)
            return calendar.date(from: components) ?? entry.createdAt
        }

        let composer = WeeklyLetterComposer(calendar: calendar)
        for (weekStart, entriesInWeek) in groupedEntries {
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            if let letter = composer.compose(
                entries: entriesInWeek.sorted { $0.createdAt < $1.createdAt },
                weekStart: weekStart,
                weekEnd: weekEnd,
                generatedAt: weekEnd
            ) {
                modelContext.insert(letter)
            }
        }
    }

    private static var treasureCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}

private enum GrowthSeedPreset: String {
    case demo

    func makeRecords(headerConfig: HomeHeaderConfig) -> [RecordItem] {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: headerConfig.birthDate)
        let heightSamples: [(Int, Double)] = [
            (7, 52.8),
            (34, 57.6),
            (63, 62.4),
            (91, 67.1),
            (121, 71.8),
        ]
        let weightSamples: [(Int, Double)] = [
            (7, 3.5),
            (34, 4.8),
            (63, 6.2),
            (91, 7.0),
            (121, 7.8),
        ]

        let heightRecords = heightSamples.map { dayOffset, value in
            RecordItem(
                timestamp: calendar.date(byAdding: .day, value: dayOffset, to: anchor) ?? anchor,
                type: RecordType.height.rawValue,
                value: value
            )
        }
        let weightRecords = weightSamples.map { dayOffset, value in
            RecordItem(
                timestamp: calendar.date(byAdding: .day, value: dayOffset, to: anchor) ?? anchor,
                type: RecordType.weight.rawValue,
                value: value
            )
        }

        return heightRecords + weightRecords
    }
}

private enum GrowthEntryLaunchMode: String {
    case ruler
    case manual
}

private enum TreasureSeedPreset: String {
    case demo

    func makeEntries(headerConfig: HomeHeaderConfig, calendar: Calendar) -> [MemoryEntry] {
        let now = calendar.startOfDay(for: .now)
        let samples: [(Int, String?, Bool)] = [
            (-52, "第一次认真看向窗外。", false),
            (-36, "会翻身了\n晚上趴着抬头看了很久。", true),
            (-8, nil, false),
            (-5, "洗完澡以后，安静地靠在怀里。", false),
            (-1, "午后的小睡醒得很轻。", false),
        ]

        return samples.compactMap { dayOffset, note, isMilestone in
            let createdAt = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            let ageInDays = max(
                calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: headerConfig.birthDate),
                    to: calendar.startOfDay(for: createdAt)
                ).day ?? 0,
                0
            )

            return MemoryEntry(
                createdAt: createdAt,
                ageInDays: ageInDays,
                imageLocalPaths: [],
                note: note,
                isMilestone: isMilestone
            )
        }
    }
}
