import Foundation
import SwiftData
@testable import sprout

@MainActor
struct TestEnvironment {
    let store: HomeStore
    let recordRepository: RecordRepository
    let growthRepository: GrowthRecordRepository
    let treasureRepository: TreasureRepository
    let modelContext: ModelContext
    let now: MutableNow
    let defaults: UserDefaults
    let localizationService: LocalizationService

    func makeBabyRepository(activeBabyState: ActiveBabyState? = nil) -> BabyRepository {
        BabyRepository(modelContext: modelContext, activeBabyState: activeBabyState)
    }
}

@MainActor
final class MutableNow {
    var value: Date

    init(_ value: Date) {
        self.value = value
    }
}

@MainActor
func makeTestEnvironment(now initialDate: Date) throws -> TestEnvironment {
    let schema = SproutSchemaRegistry.schema
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try SproutContainerFactory.make(
        schema: schema,
        modelConfiguration: configuration
    )
    let modelContext = ModelContext(container)
    let now = MutableNow(initialDate)
    let recordRepository = RecordRepository(modelContext: modelContext, nowProvider: { now.value })
    let growthRepository = GrowthRecordRepository(modelContext: modelContext)
    let treasureRepository = TreasureRepository(modelContext: modelContext)

    let suiteName = "sproutTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let calendar = Calendar(identifier: .gregorian)
    let localizationService = LocalizationService(
        bundle: .main,
        locale: Locale(identifier: "zh-Hans"),
        language: .simplifiedChinese
    )
    let store = HomeStore(
        headerConfig: .placeholder,
        recordRepository: recordRepository,
        formatter: TimelineContentFormatter(localizationService: localizationService),
        localizationService: localizationService,
        sleepSessionRepository: SleepSessionRepository(defaults: defaults, storageKey: "active_sleep_session_test"),
        calendar: calendar,
        historyPageSize: 20,
        dateProvider: { now.value }
    )

    return TestEnvironment(
        store: store,
        recordRepository: recordRepository,
        growthRepository: growthRepository,
        treasureRepository: treasureRepository,
        modelContext: modelContext,
        now: now,
        defaults: defaults,
        localizationService: localizationService
    )
}

@MainActor
func makeGrowthStore(
    environment: TestEnvironment,
    preferenceStore: GrowthMetricPreferenceStore? = nil,
    productConfig: GrowthProductConfig = .appDefault,
    chartInteractionController: GrowthChartInteractionController = GrowthChartInteractionController()
) -> GrowthStore {
    let calendar = Calendar(identifier: .gregorian)

    return GrowthStore(
        headerConfig: .placeholder,
        repository: environment.growthRepository,
        formatter: GrowthFormatter(calendar: calendar),
        localizationService: environment.localizationService,
        textRenderer: GrowthTextRenderer(localizationService: environment.localizationService),
        referenceRangeStore: GrowthReferenceRangeStore(),
        metricPreferenceStore: preferenceStore ?? GrowthMetricPreferenceStore(
            defaults: environment.defaults,
            storageKey: "growth.metric.preference.test"
        ),
        chartInteractionController: chartInteractionController,
        productConfig: productConfig,
        calendar: calendar,
        dateProvider: { environment.now.value }
    )
}

@MainActor
func makeTreasureStore(
    environment: TestEnvironment,
    monthHintStore: TreasureMonthHintStore? = nil,
    imageRemover: @escaping @MainActor ([String]) -> Void = { _ in }
) -> TreasureStore {
    let calendar = Calendar(identifier: .gregorian)

    return TreasureStore(
        headerConfig: .placeholder,
        repository: environment.treasureRepository,
        timelineBuilder: TreasureTimelineBuilder(calendar: calendar),
        monthAnchorBuilder: TreasureMonthAnchorBuilder(calendar: calendar),
        weeklyLetterComposer: WeeklyLetterComposer(calendar: calendar),
        monthHintStore: monthHintStore ?? TreasureMonthHintStore(
            defaults: environment.defaults,
            storageKey: "treasure.month.hint.test"
        ),
        calendar: calendar,
        dateProvider: { environment.now.value },
        imageRemover: imageRemover
    )
}
