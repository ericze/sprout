import Foundation

struct GrowthTextRenderer {
    let localizationService: LocalizationService
    let localeFormatter: LocaleFormatter

    init(
        localizationService: LocalizationService = .current,
        localeFormatter: LocaleFormatter? = nil
    ) {
        self.localizationService = localizationService
        self.localeFormatter = localeFormatter ?? LocaleFormatter(
            locale: localizationService.locale,
            calendar: .autoupdatingCurrent,
            localizationService: localizationService
        )
    }

    func metricTitle(_ metric: GrowthMetric) -> String {
        switch metric {
        case .height:
            return L10n.text(metric.titleLocalizationKey, service: localizationService, en: "Height", zh: "身高")
        case .weight:
            return L10n.text(metric.titleLocalizationKey, service: localizationService, en: "Weight", zh: "体重")
        case .headCircumference:
            return L10n.text(metric.titleLocalizationKey, service: localizationService, en: "Head Circumference", zh: "头围")
        }
    }

    func metricEntryTitle(_ metric: GrowthMetric) -> String {
        switch metric {
        case .height:
            return L10n.text(metric.entryTitleLocalizationKey, service: localizationService, en: "Record height", zh: "记录身高")
        case .weight:
            return L10n.text(metric.entryTitleLocalizationKey, service: localizationService, en: "Record weight", zh: "记录体重")
        case .headCircumference:
            return L10n.text(metric.entryTitleLocalizationKey, service: localizationService, en: "Record head circumference", zh: "记录头围")
        }
    }

    func metricEmptyText(_ metric: GrowthMetric) -> String {
        switch metric {
        case .height:
            return L10n.text(metric.emptyLocalizationKey, service: localizationService, en: "No height records yet", zh: "还没有身高记录")
        case .weight:
            return L10n.text(metric.emptyLocalizationKey, service: localizationService, en: "No weight records yet", zh: "还没有体重记录")
        case .headCircumference:
            return L10n.text(metric.emptyLocalizationKey, service: localizationService, en: "No head circumference records yet", zh: "还没有头围记录")
        }
    }

    func unitSymbol(for metric: GrowthMetric) -> String {
        switch metric {
        case .height:
            return L10n.text(metric.unitLocalizationKey, service: localizationService, en: "cm", zh: "cm")
        case .weight:
            return L10n.text(metric.unitLocalizationKey, service: localizationService, en: "kg", zh: "kg")
        case .headCircumference:
            return L10n.text(metric.unitLocalizationKey, service: localizationService, en: "cm", zh: "cm")
        }
    }

    func editableValue(_ value: Double) -> String {
        localeFormatter.decimal(value, minFractionDigits: 1, maxFractionDigits: 1)
    }

    func valueText(_ value: Double, metric: GrowthMetric) -> String {
        localeFormatter.localizedSymbolValue(
            value,
            symbol: unitSymbol(for: metric),
            minFractionDigits: 1,
            maxFractionDigits: 1
        )
    }

    func metaSummary(_ metaInfo: GrowthMetaInfo) -> String {
        guard
            let latestValue = metaInfo.latestValue,
            let latestRecordedAt = metaInfo.latestRecordedAt
        else {
            return metricEmptyText(metaInfo.metric)
        }

        return L10n.format(
            "growth.meta.latest_format",
            service: localizationService,
            locale: localeFormatter.locale,
            en: "Latest record: %@ · %@",
            zh: "最新记录：%@ · %@",
            arguments: [
                valueText(latestValue, metric: metaInfo.metric),
                localeFormatter.relativeDay(from: latestRecordedAt, to: metaInfo.referenceDate)
            ]
        )
    }

    func tooltipAgeText(ageInDays: Int) -> String {
        localeFormatter.ageText(fromDays: ageInDays, style: .detail)
    }

    func axisAgeText(ageInDays: Int) -> String {
        localeFormatter.ageText(fromDays: ageInDays, style: .axis)
    }

    func yAxisLabelText(_ label: GrowthYAxisLabel, metric: GrowthMetric) -> String {
        valueText(label.value, metric: metric)
    }

    func aiText(_ message: GrowthAIMessage) -> String {
        switch message.kind {
        case .waitingFirstRecord:
            return L10n.format(
                "growth.ai.waiting_first_record_format",
                service: localizationService,
                locale: localeFormatter.locale,
                en: "Waiting for the first %@ record",
                zh: "✨ 等待第一条%@记录",
                arguments: [metricTitle(message.metric)]
            )
        case .inviteFirstRecord:
            return L10n.format(
                "growth.ai.invite_first_record_format",
                service: localizationService,
                locale: localeFormatter.locale,
                en: "Record the first %@ entry. The line can begin from here.",
                zh: "✨ 记录第一条%@数据，生命线会从这里开始。",
                arguments: [metricTitle(message.metric)]
            )
        case .firstRecordLogged:
            return L10n.format(
                "growth.ai.first_record_logged_format",
                service: localizationService,
                locale: localeFormatter.locale,
                en: "Logged the first %@ record",
                zh: "✨ 已记录第一条%@数据",
                arguments: [metricTitle(message.metric)]
            )
        case let .change(intervalDays, direction, deltaValue):
            let intervalText = localeFormatter.ageText(fromDays: intervalDays, style: .detail)
            switch direction {
            case .unchanged:
                return L10n.format(
                    "growth.ai.change_unchanged_format",
                    service: localizationService,
                    locale: localeFormatter.locale,
                    en: "Compared with %@ ago, %@ stayed the same.",
                    zh: "距离上次记录过去了 %@，%@与上次持平。",
                    arguments: [intervalText, metricTitle(message.metric)]
                )
            case .increased:
                return L10n.format(
                    "growth.ai.change_increased_format",
                    service: localizationService,
                    locale: localeFormatter.locale,
                    en: "Compared with %@ ago, %@ increased by %@.",
                    zh: "距离上次记录过去了 %@，%@增加了 %@。",
                    arguments: [intervalText, metricTitle(message.metric), valueText(deltaValue, metric: message.metric)]
                )
            case .decreased:
                return L10n.format(
                    "growth.ai.change_decreased_format",
                    service: localizationService,
                    locale: localeFormatter.locale,
                    en: "Compared with %@ ago, %@ decreased by %@.",
                    zh: "距离上次记录过去了 %@，%@较上次减少了 %@。",
                    arguments: [intervalText, metricTitle(message.metric), valueText(deltaValue, metric: message.metric)]
                )
            }
        }
    }

    func aiCollapsedText(_ message: GrowthAIMessage) -> String {
        switch message.kind {
        case .waitingFirstRecord:
            return aiText(message)
        case .inviteFirstRecord:
            return aiText(message)
        case .firstRecordLogged:
            return aiText(message)
        case let .change(intervalDays, _, _):
            return L10n.format(
                "growth.ai.collapsed_change_format",
                service: localizationService,
                locale: localeFormatter.locale,
                en: "Logged a change since %@ ago",
                zh: "✨ 记录了距上次%@的变化",
                arguments: [localeFormatter.ageText(fromDays: intervalDays, style: .detail)]
            )
        }
    }

    func undoMessage(value: Double, metric: GrowthMetric) -> String {
        L10n.format(
            "growth.undo.saved_format",
            service: localizationService,
            locale: localeFormatter.locale,
            en: "Saved %@",
            zh: "已记录%@",
            arguments: [valueText(value, metric: metric)]
        )
    }

    func milestoneUndoMessage() -> String {
        L10n.text(
            "growth.milestone.undo",
            service: localizationService,
            en: "Milestone saved",
            zh: "里程碑已记录"
        )
    }

    func unavailableMessage() -> String {
        L10n.text(
            "growth.error.unavailable",
            service: localizationService,
            en: "Growth data is unavailable right now",
            zh: "成长数据暂不可用"
        )
    }

    func loadFailedMessage() -> String {
        L10n.text(
            "growth.error.load_failed",
            service: localizationService,
            en: "Failed to load growth data",
            zh: "成长数据加载失败"
        )
    }
}
