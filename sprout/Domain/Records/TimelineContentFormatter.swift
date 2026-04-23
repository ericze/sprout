import Foundation

struct TimelineContentFormatter {
    private let localizationService: LocalizationService
    private let localeFormatter: LocaleFormatter

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

    func makeDisplayItems(from records: [RecordItem]) -> [TimelineDisplayItem] {
        records.compactMap(makeDisplayItem)
    }

    func makeDisplayItem(from record: RecordItem) -> TimelineDisplayItem? {
        guard let recordType = record.recordType else { return nil }

        switch recordType {
        case .milk:
            let content = makeFeedingContent(from: record)
            return TimelineDisplayItem(
                id: record.id,
                recordID: record.id,
                timestamp: record.timestamp,
                cardStyle: .standard,
                leadingIcon: .milk,
                title: content.title,
                subtitle: content.subtitle,
                imagePath: nil,
                type: .milk
            )
        case .diaper:
            return TimelineDisplayItem(
                id: record.id,
                recordID: record.id,
                timestamp: record.timestamp,
                cardStyle: .standard,
                leadingIcon: .diaper,
                title: formatDiaperTitle(subType: record.subType),
                subtitle: nil,
                imagePath: nil,
                type: .diaper
            )
        case .sleep:
            return TimelineDisplayItem(
                id: record.id,
                recordID: record.id,
                timestamp: record.timestamp,
                cardStyle: .standard,
                leadingIcon: .sleep,
                title: formatSleepTitle(durationInSeconds: record.value),
                subtitle: nil,
                imagePath: nil,
                type: .sleep
            )
        case .food:
            let title = formatFoodTitle(tags: record.tags, note: record.note)
            let hasImage = isUsableImagePath(record.imageURL)

            return TimelineDisplayItem(
                id: record.id,
                recordID: record.id,
                timestamp: record.timestamp,
                cardStyle: hasImage ? .foodPhoto : .standard,
                leadingIcon: .food,
                title: title,
                subtitle: nil,
                imagePath: hasImage ? record.imageURL : nil,
                type: .food
            )
        case .height, .weight, .headCircumference:
            return nil
        }
    }

    func makeFeedingContent(from record: RecordItem) -> (title: String, subtitle: String?) {
        let leftSeconds = max(record.leftNursingSeconds, 0)
        let rightSeconds = max(record.rightNursingSeconds, 0)
        let totalNursingSeconds = leftSeconds + rightSeconds
        let bottleAmountMl = record.bottleAmountMl
        let nursingDuration = localeFormatter.minuteDurationText(floorMinutes(totalNursingSeconds))
        let bottleAmount = localeFormatter.localizedSymbolValue(
            bottleAmountMl,
            symbol: L10n.text(
                "unit.milliliter.short",
                service: localizationService,
                en: "mL",
                zh: "ml"
            )
        )

        if totalNursingSeconds > 0, bottleAmountMl > 0 {
            return (
                L10n.format(
                    "timeline.milk.mixed_format",
                    service: localizationService,
                    locale: localeFormatter.locale,
                    en: "Nursing %@ + %@ bottle",
                    zh: "亲喂 %@ + %@ 瓶喂",
                    arguments: [nursingDuration, bottleAmount]
                ),
                makeNursingSubtitle(leftSeconds: leftSeconds, rightSeconds: rightSeconds)
            )
        }

        if totalNursingSeconds > 0 {
            return (
                L10n.format(
                    "timeline.milk.nursing_only_format",
                    service: localizationService,
                    locale: localeFormatter.locale,
                    en: "Nursing %@",
                    zh: "亲喂 %@",
                    arguments: [nursingDuration]
                ),
                makeNursingSubtitle(leftSeconds: leftSeconds, rightSeconds: rightSeconds)
            )
        }

        if bottleAmountMl > 0 {
            return (
                L10n.format(
                    "timeline.milk.bottle_only_format",
                    service: localizationService,
                    locale: localeFormatter.locale,
                    en: "%@ bottle",
                    zh: "%@ 瓶喂",
                    arguments: [bottleAmount]
                ),
                nil
            )
        }

        return (
            L10n.text(
                "timeline.milk.default_title",
                service: localizationService,
                en: "Feeding",
                zh: "喂奶"
            ),
            nil
        )
    }

    func formatDiaperTitle(subType: String?) -> String {
        guard let subType, let diaperSubtype = DiaperSubtype(rawValue: subType) else {
            return L10n.text(
                "timeline.diaper.default_title",
                service: localizationService,
                en: "Diaper",
                zh: "尿布"
            )
        }
        return L10n.text(
            diaperSubtype.localizationKey,
            service: localizationService,
            en: englishDiaperTitle(for: diaperSubtype),
            zh: chineseDiaperTitle(for: diaperSubtype)
        )
    }

    func formatSleepTitle(durationInSeconds: Double?) -> String {
        guard let durationInSeconds, durationInSeconds > 0 else {
            return L10n.text(
                "timeline.sleep.default_title",
                service: localizationService,
                en: "Sleep",
                zh: "睡眠"
            )
        }
        return L10n.format(
            "timeline.sleep.duration_title_format",
            service: localizationService,
            locale: localeFormatter.locale,
            en: "Slept %@",
            zh: "睡了 %@",
            arguments: [formatSleepDuration(durationInSeconds: durationInSeconds)]
        )
    }

    func formatSleepDuration(durationInSeconds: Double) -> String {
        localeFormatter.durationText(seconds: max(durationInSeconds, 60))
    }

    func formatFoodTitle(tags: [String]?, note: String?) -> String {
        let normalizedTags = tags?.map(\.trimmed).filter { !$0.isEmpty } ?? []
        let normalizedNote = note?.trimmed

        let limitedTags = Array(normalizedTags.prefix(3))
        let joinedTags = localeFormatter.list(limitedTags)
        let tagsTitle = limitedTags.isEmpty
            ? nil
            : L10n.format(
                "timeline.food.tags_only_format",
                service: localizationService,
                locale: localeFormatter.locale,
                en: "Ate %@",
                zh: "吃了%@",
                arguments: [joinedTags]
            )
        let noteTitle = (normalizedNote?.isEmpty == false) ? normalizedNote : nil

        switch (tagsTitle, noteTitle) {
        case let (tagsTitle?, noteTitle?):
            return L10n.format(
                "timeline.food.tags_and_note_format",
                service: localizationService,
                locale: localeFormatter.locale,
                en: "%@ / %@",
                zh: "%@ / %@",
                arguments: [tagsTitle, noteTitle]
            )
        case let (tagsTitle?, nil):
            return tagsTitle
        case let (nil, noteTitle?):
            return noteTitle
        default:
            return L10n.text(
                "timeline.food.default_title",
                service: localizationService,
                en: "Solids",
                zh: "辅食"
            )
        }
    }

    func defaultFeedingTitle() -> String {
        L10n.text(
            "timeline.milk.default_title",
            service: localizationService,
            en: "Feeding",
            zh: "喂奶"
        )
    }

    func feedingSubmitButtonTitle(totalNursingSeconds: Int, bottleAmountMl: Int) -> String {
        let totalMinutes = floorMinutes(totalNursingSeconds)
        let nursingDuration = localeFormatter.minuteDurationText(totalMinutes)
        let bottleAmount = localeFormatter.localizedSymbolValue(
            bottleAmountMl,
            symbol: L10n.text(
                "unit.milliliter.short",
                service: localizationService,
                en: "mL",
                zh: "ml"
            )
        )

        if totalNursingSeconds > 0, bottleAmountMl > 0 {
            return L10n.format(
                "home.sheet.milk.submit.mixed_format",
                service: localizationService,
                locale: localeFormatter.locale,
                en: "Record %@ nursing + %@ bottle",
                zh: "记录 %@ 亲喂 + %@ 瓶喂",
                arguments: [nursingDuration, bottleAmount]
            )
        }

        if totalNursingSeconds > 0 {
            return L10n.format(
                "home.sheet.milk.submit.nursing_format",
                service: localizationService,
                locale: localeFormatter.locale,
                en: "Record %@ nursing",
                zh: "记录 %@ 亲喂",
                arguments: [nursingDuration]
            )
        }

        if bottleAmountMl > 0 {
            return L10n.format(
                "home.sheet.milk.submit.bottle_format",
                service: localizationService,
                locale: localeFormatter.locale,
                en: "Record %@ bottle",
                zh: "记录 %@ 瓶喂",
                arguments: [bottleAmount]
            )
        }

        return L10n.text(
            "home.sheet.milk.submit.default",
            service: localizationService,
            en: "Done",
            zh: "完成记录"
        )
    }

    func savedRecordMessage(title: String) -> String {
        L10n.format(
            "home.undo.saved_record_format",
            service: localizationService,
            locale: localeFormatter.locale,
            en: "Saved %@",
            zh: "已记录%@",
            arguments: [title]
        )
    }

    func endedSleepMessage() -> String {
        L10n.text(
            "home.undo.ended_sleep",
            service: localizationService,
            en: "Ended sleep",
            zh: "已结束睡眠"
        )
    }

    func savedFoodMessage() -> String {
        L10n.text(
            "home.undo.saved_food",
            service: localizationService,
            en: "Saved solids",
            zh: "已记录一顿辅食"
        )
    }

    private func isUsableImagePath(_ path: String?) -> Bool {
        guard let path, !path.trimmed.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    private func makeNursingSubtitle(leftSeconds: Int, rightSeconds: Int) -> String? {
        let leftMinutes = floorMinutes(leftSeconds)
        let rightMinutes = floorMinutes(rightSeconds)

        guard leftMinutes > 0 || rightMinutes > 0 else { return nil }
        let leftText = localeFormatter.minuteDurationText(leftMinutes)
        let rightText = localeFormatter.minuteDurationText(rightMinutes)

        return L10n.format(
            "timeline.milk.side_subtitle_format",
            service: localizationService,
            locale: localeFormatter.locale,
            en: "Left %@ · Right %@",
            zh: "左 %@ · 右 %@",
            arguments: [leftText, rightText]
        )
    }

    private func floorMinutes(_ seconds: Int) -> Int {
        max(0, seconds / 60)
    }

    private func englishDiaperTitle(for subtype: DiaperSubtype) -> String {
        switch subtype {
        case .pee:
            "Diaper: Pee"
        case .poop:
            "Diaper: Poop"
        case .both:
            "Diaper: Both"
        }
    }

    private func chineseDiaperTitle(for subtype: DiaperSubtype) -> String {
        switch subtype {
        case .pee:
            "尿布：小便"
        case .poop:
            "尿布：大便"
        case .both:
            "尿布：都有"
        }
    }
}
