import Foundation

struct TimelineContentFormatter {
    nonisolated init() {}

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
        case .height, .weight:
            return nil
        }
    }

    func makeFeedingContent(from record: RecordItem) -> (title: String, subtitle: String?) {
        let leftSeconds = max(record.leftNursingSeconds, 0)
        let rightSeconds = max(record.rightNursingSeconds, 0)
        let totalNursingSeconds = leftSeconds + rightSeconds
        let bottleAmountMl = record.bottleAmountMl

        if totalNursingSeconds > 0, bottleAmountMl > 0 {
            return (
                "亲喂 \(floorMinutes(totalNursingSeconds))分钟 + \(bottleAmountMl)ml 瓶喂",
                makeNursingSubtitle(leftSeconds: leftSeconds, rightSeconds: rightSeconds)
            )
        }

        if totalNursingSeconds > 0 {
            return (
                "亲喂 \(floorMinutes(totalNursingSeconds))分钟",
                makeNursingSubtitle(leftSeconds: leftSeconds, rightSeconds: rightSeconds)
            )
        }

        if bottleAmountMl > 0 {
            return ("\(bottleAmountMl)ml 瓶喂", nil)
        }

        return ("记录了一次喂奶", nil)
    }

    func formatDiaperTitle(subType: String?) -> String {
        guard let subType, let diaperSubtype = DiaperSubtype(rawValue: subType) else {
            return "记录了一次尿布"
        }
        return diaperSubtype.title
    }

    func formatSleepTitle(durationInSeconds: Double?) -> String {
        guard let durationInSeconds, durationInSeconds > 0 else {
            return "记录了一次睡眠"
        }
        return "睡了 \(formatSleepDuration(durationInSeconds: durationInSeconds))"
    }

    func formatSleepDuration(durationInSeconds: Double) -> String {
        let totalMinutes = max(Int(durationInSeconds / 60), 1)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(totalMinutes)分钟"
        }

        return minutes == 0 ? "\(hours)小时" : "\(hours)小时\(minutes)分"
    }

    func formatFoodTitle(tags: [String]?, note: String?) -> String {
        let normalizedTags = tags?.map(\.trimmed).filter { !$0.isEmpty } ?? []
        let normalizedNote = note?.trimmed

        let limitedTags = Array(normalizedTags.prefix(3))
        let tagsTitle = limitedTags.isEmpty ? nil : "吃了\(limitedTags.joined(separator: "、"))"
        let noteTitle = (normalizedNote?.isEmpty == false) ? normalizedNote : nil

        switch (tagsTitle, noteTitle) {
        case let (tagsTitle?, noteTitle?):
            return "\(tagsTitle) / \(noteTitle)"
        case let (tagsTitle?, nil):
            return tagsTitle
        case let (nil, noteTitle?):
            return noteTitle
        default:
            return "记录了一顿辅食"
        }
    }

    private func isUsableImagePath(_ path: String?) -> Bool {
        guard let path, !path.trimmed.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    private func makeNursingSubtitle(leftSeconds: Int, rightSeconds: Int) -> String? {
        let leftMinutes = floorMinutes(leftSeconds)
        let rightMinutes = floorMinutes(rightSeconds)

        guard leftMinutes > 0 || rightMinutes > 0 else { return nil }
        return "左 \(leftMinutes)m · 右 \(rightMinutes)m"
    }

    private func floorMinutes(_ seconds: Int) -> Int {
        max(0, seconds / 60)
    }
}
