import Foundation

struct WeeklyLetterComposer {
    private let calendar: Calendar
    private let language: AppLanguage
    private let bannedTerms = [
        "击败", "超越", "落后", "领先", "优秀", "达标", "偏瘦", "偏胖",
        "健康", "发育", "奖励", "解锁", "成就", "荣耀", "任务完成",
        "beat", "exceed", "behind", "ahead", "excellent", "goal", "underweight",
        "overweight", "healthy", "development", "reward", "unlock", "achievement",
        "glory", "mission complete",
    ]

    init(calendar: Calendar = .current, language: AppLanguage = LocalizationService.current.language) {
        self.calendar = calendar
        self.language = language
    }

    func compose(
        entries: [MemoryEntry],
        weekStart: Date,
        weekEnd: Date,
        generatedAt: Date
    ) -> WeeklyLetter? {
        guard !entries.isEmpty else { return nil }

        let normalizedEntries = entries.sorted { $0.createdAt < $1.createdAt }
        let photoCount = normalizedEntries.reduce(into: 0) { partialResult, entry in
            partialResult += normalizedImageCount(for: entry)
        }
        let textCount = normalizedEntries.filter { !($0.note?.trimmed.isEmpty ?? true) }.count
        let milestoneCount = normalizedEntries.filter(\.isMilestone).count
        let density = makeDensity(entryCount: normalizedEntries.count, milestoneCount: milestoneCount)
        let collapsedText = makeCollapsedText(for: density)
        let expandedText = makeExpandedText(
            density: density,
            entries: normalizedEntries,
            photoCount: photoCount,
            textCount: textCount,
            milestoneCount: milestoneCount
        )

        guard isAllowed(collapsedText, density: density, isCollapsed: true),
              isAllowed(expandedText, density: density, isCollapsed: false) else {
            return nil
        }

        return WeeklyLetter(
            weekStart: calendar.startOfDay(for: weekStart),
            weekEnd: calendar.startOfDay(for: weekEnd),
            density: density,
            collapsedText: collapsedText,
            expandedText: expandedText,
            generatedAt: generatedAt
        )
    }

    private func makeDensity(entryCount: Int, milestoneCount: Int) -> WeeklyLetterDensity {
        if milestoneCount > 0 || entryCount >= 5 {
            return .dense
        }
        if (2...4).contains(entryCount) {
            return .normal
        }
        return .silent
    }

    private func makeCollapsedText(for density: WeeklyLetterDensity) -> String {
        switch language {
        case .english:
            switch density {
            case .silent:
                return "A quiet week."
            case .normal:
                return "A letter arrived for this week."
            case .dense:
                return "A thicker letter arrived this week."
            }
        case .simplifiedChinese:
            switch density {
            case .silent:
                return "这一周很安静。"
            case .normal:
                return "时间寄来了一封这一周的信。"
            case .dense:
                return "这一周留下了一封更厚一点的信。"
            }
        }
    }

    private func makeExpandedText(
        density: WeeklyLetterDensity,
        entries: [MemoryEntry],
        photoCount: Int,
        textCount: Int,
        milestoneCount: Int
    ) -> String {
        let firstNoteSnippet = entries
            .compactMap { $0.note?.trimmed.nilIfEmpty }
            .first?
            .prefix(18) ?? ""

        switch language {
        case .english:
            return makeEnglishExpandedText(
                density: density,
                entries: entries,
                photoCount: photoCount,
                textCount: textCount,
                milestoneCount: milestoneCount,
                firstNoteSnippet: firstNoteSnippet
            )
        case .simplifiedChinese:
            return makeChineseExpandedText(
                density: density,
                entries: entries,
                photoCount: photoCount,
                textCount: textCount,
                milestoneCount: milestoneCount,
                firstNoteSnippet: firstNoteSnippet
            )
        }
    }

    private func makeEnglishExpandedText(
        density: WeeklyLetterDensity,
        entries: [MemoryEntry],
        photoCount: Int,
        textCount: Int,
        milestoneCount: Int,
        firstNoteSnippet: String
    ) -> String {
        switch density {
        case .silent:
            return "One memory, quietly kept."
        case .normal:
            var parts = ["\(entries.count) memories this week"]
            if photoCount > 0 {
                parts.append("\(photoCount) photo\(photoCount == 1 ? "" : "s")")
            }
            if textCount > 0 {
                parts.append("\(textCount) note\(textCount == 1 ? "" : "s")")
            }
            let joined = parts.joined(separator: ", ")
            return "\(joined). Small moments stayed here, gently and without hurry."
        case .dense:
            var header = "More than usual this week."
            if milestoneCount > 0 {
                header += " \(milestoneCount) star\(milestoneCount == 1 ? "" : "s") were gently marked."
            }
            let body = "\(entries.count) memories spread across the week, with \(photoCount) photo\(photoCount == 1 ? "" : "s") and \(textCount) note\(textCount == 1 ? "" : "s") tucked in."
            let ending: String
            if firstNoteSnippet.isEmpty {
                ending = "They can stay quiet and still be kept."
            } else {
                ending = "A moment like \"\(firstNoteSnippet)\" stays safely here."
            }
            return "\(header) \(body) \(ending)"
        }
    }

    private func makeChineseExpandedText(
        density: WeeklyLetterDensity,
        entries: [MemoryEntry],
        photoCount: Int,
        textCount: Int,
        milestoneCount: Int,
        firstNoteSnippet: String
    ) -> String {
        switch density {
        case .silent:
            return "这一周只留下一条记忆，安静收好。"
        case .normal:
            var segments = ["这一周留下了 \(entries.count) 条记忆"]
            if photoCount > 0 {
                segments.append("\(photoCount) 张照片")
            }
            if textCount > 0 {
                segments.append("\(textCount) 段文字")
            }
            let joined = segments.joined(separator: "，")
            return "\(joined)。几件小事安静地留了下来，时间也在这些片刻里慢慢往前。"
        case .dense:
            var prefix = "这一周比平时更满一些。"
            if milestoneCount > 0 {
                prefix += " 其中有 \(milestoneCount) 个小小的星标。"
            }

            let middle = "照片和文字让这一页更厚了一点，\(entries.count) 条记忆慢慢铺开。"
            let ending: String
            if firstNoteSnippet.isEmpty {
                ending = "它们不需要被张扬，只要在翻到这里时能被重新看见。"
            } else {
                ending = "像“\(firstNoteSnippet)”这样的片刻，也被稳稳留了下来。"
            }
            return "\(prefix)\(middle)\(ending)"
        }
    }

    private func isAllowed(_ text: String, density: WeeklyLetterDensity, isCollapsed: Bool) -> Bool {
        guard !text.trimmed.isEmpty else { return false }
        guard bannedTerms.allSatisfy({ !text.contains($0) }) else { return false }

        let maxLength: Int
        if isCollapsed {
            maxLength = language == .english ? 40 : 30
        } else {
            switch density {
            case .silent:
                maxLength = 30
            case .normal:
                maxLength = 100
            case .dense:
                maxLength = 250
            }
        }

        return text.count <= maxLength
    }

    private func normalizedImageCount(for entry: MemoryEntry) -> Int {
        entry.imageLocalPaths.count
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
