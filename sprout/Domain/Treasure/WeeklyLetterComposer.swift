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
        milestones: [GrowthMilestoneEntry] = [],
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
        let growthMilestoneCount = milestones.count
        let density = makeDensity(
            entryCount: normalizedEntries.count,
            milestoneCount: milestoneCount,
            growthMilestoneCount: growthMilestoneCount
        )
        let collapsedText = makeCollapsedText(for: density)
        let expandedText = makeExpandedText(
            density: density,
            entries: normalizedEntries,
            photoCount: photoCount,
            textCount: textCount,
            milestoneCount: milestoneCount,
            growthMilestones: milestones
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

    func compose(
        digest: WeeklyDigest,
        generatedAt: Date,
        languageCode: String
    ) -> WeeklyLetter? {
        guard !digest.memories.isEmpty else { return nil }

        let normalizedEntries = digest.memories.sorted { $0.createdAt < $1.createdAt }
        let density = makeDensity(
            entryCount: normalizedEntries.count,
            milestoneCount: digest.milestoneCount
        )
        let collapsedText = makeCollapsedText(for: density)
        let expandedText = makeRichExpandedText(
            density: density,
            digest: digest,
            entries: normalizedEntries
        )

        guard isAllowed(collapsedText, density: density, isCollapsed: true),
              isAllowed(expandedText, density: density, isCollapsed: false) else {
            return nil
        }

        let sourceSignature = buildSourceSignature(digest: digest)

        return WeeklyLetter(
            weekStart: calendar.startOfDay(for: digest.weekStart),
            weekEnd: calendar.startOfDay(for: digest.weekEnd),
            density: density,
            collapsedText: collapsedText,
            expandedText: expandedText,
            languageCode: languageCode,
            sourceSignature: sourceSignature,
            generatedBy: "WeeklyDigestBuilder",
            generatedAt: generatedAt
        )
    }

    private func makeDensity(entryCount: Int, milestoneCount: Int, growthMilestoneCount: Int = 0) -> WeeklyLetterDensity {
        if milestoneCount > 0 || growthMilestoneCount > 0 || entryCount >= 5 {
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
        milestoneCount: Int,
        growthMilestones: [GrowthMilestoneEntry] = []
    ) -> String {
        let firstNoteSnippet = entries
            .compactMap { $0.note?.trimmed.nilIfEmpty }
            .first
            .map { String($0.prefix(18)) } ?? ""

        switch language {
        case .english:
            return makeEnglishExpandedText(
                density: density,
                entries: entries,
                photoCount: photoCount,
                textCount: textCount,
                milestoneCount: milestoneCount,
                firstNoteSnippet: firstNoteSnippet,
                growthMilestones: growthMilestones
            )
        case .simplifiedChinese:
            return makeChineseExpandedText(
                density: density,
                entries: entries,
                photoCount: photoCount,
                textCount: textCount,
                milestoneCount: milestoneCount,
                firstNoteSnippet: firstNoteSnippet,
                growthMilestones: growthMilestones
            )
        }
    }

    private func makeEnglishExpandedText(
        density: WeeklyLetterDensity,
        entries: [MemoryEntry],
        photoCount: Int,
        textCount: Int,
        milestoneCount: Int,
        firstNoteSnippet: String,
        growthMilestones: [GrowthMilestoneEntry] = []
    ) -> String {
        let growthSummary = makeGrowthMilestoneSummaryEnglish(growthMilestones)

        switch density {
        case .silent:
            if let summary = growthSummary {
                return "One memory, quietly kept. \(summary)"
            }
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
            if let summary = growthSummary {
                return "\(joined). \(summary) Small moments stayed here, gently and without hurry."
            }
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
            if let summary = growthSummary {
                return "\(header) \(body) \(summary) \(ending)"
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
        firstNoteSnippet: String,
        growthMilestones: [GrowthMilestoneEntry] = []
    ) -> String {
        let growthSummary = makeGrowthMilestoneSummaryChinese(growthMilestones)

        switch density {
        case .silent:
            if let summary = growthSummary {
                return "这一周只留下一条记忆，安静收好。\(summary)"
            }
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
            if let summary = growthSummary {
                return "\(joined)。\(summary)几件小事安静地留了下来，时间也在这些片刻里慢慢往前。"
            }
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
                ending = "像\u{201C}\(firstNoteSnippet)\u{201D}这样的片刻，也被稳稳留了下来。"
            }
            if let summary = growthSummary {
                return "\(prefix)\(middle)\(summary)\(ending)"
            }
            return "\(prefix)\(middle)\(ending)"
        }
    }

    private func makeGrowthMilestoneSummaryEnglish(_ milestones: [GrowthMilestoneEntry]) -> String? {
        guard !milestones.isEmpty else { return nil }
        let titles = milestones.map(\.title).prefix(3).joined(separator: ", ")
        let count = milestones.count
        if count == 1 {
            return "A milestone reached: \(titles)."
        }
        return "\(count) milestones reached: \(titles)."
    }

    private func makeGrowthMilestoneSummaryChinese(_ milestones: [GrowthMilestoneEntry]) -> String? {
        guard !milestones.isEmpty else { return nil }
        let titles = milestones.map(\.title).prefix(3).joined(separator: "、")
        let count = milestones.count
        return "本周宝宝达成了 \(count) 个成长里程碑：\(titles)。"
    }

    private func makeRichExpandedText(
        density: WeeklyLetterDensity,
        digest: WeeklyDigest,
        entries: [MemoryEntry]
    ) -> String {
        let firstNoteSnippet = entries
            .compactMap { $0.note?.trimmed.nilIfEmpty }
            .first
            .map { String($0.prefix(18)) } ?? ""

        switch language {
        case .english:
            return makeRichEnglishExpandedText(
                density: density,
                digest: digest,
                entries: entries,
                firstNoteSnippet: firstNoteSnippet
            )
        case .simplifiedChinese:
            return makeRichChineseExpandedText(
                density: density,
                digest: digest,
                entries: entries,
                firstNoteSnippet: firstNoteSnippet
            )
        }
    }

    private func makeRichEnglishExpandedText(
        density: WeeklyLetterDensity,
        digest: WeeklyDigest,
        entries: [MemoryEntry],
        firstNoteSnippet: String
    ) -> String {
        var sections: [String] = []
        let growthSummary = makeDigestGrowthMilestoneSummaryEnglish(digest.milestones)

        if digest.growthRecordCount > 0 {
            sections.append("\(digest.growthRecordCount) growth measurement\(digest.growthRecordCount == 1 ? "" : "s")")
        }

        if !digest.firstTasteTags.isEmpty {
            let tagList = digest.firstTasteTags.prefix(3).joined(separator: ", ")
            sections.append("new tastes: \(tagList)")
        }

        if let growthSummary {
            sections.append(growthSummary)
        }

        switch density {
        case .silent:
            if let growthSummary {
                return "One memory, quietly kept. \(growthSummary)."
            }
            return "One memory, quietly kept."
        case .normal:
            let base = "\(entries.count) memories this week"
            let photoPart = digest.photoCount > 0 ? "\(digest.photoCount) photo\(digest.photoCount == 1 ? "" : "s")" : nil
            let textPart = digest.textCount > 0 ? "\(digest.textCount) note\(digest.textCount == 1 ? "" : "s")" : nil
            var parts = [base]
            if let p = photoPart { parts.append(p) }
            if let p = textPart { parts.append(p) }
            parts.append(contentsOf: sections)
            return "\(parts.joined(separator: ", ")). Small moments stayed here, gently and without hurry."
        case .dense:
            var header = "More than usual this week."
            if digest.memoryMilestoneCount > 0 {
                header += " \(digest.memoryMilestoneCount) star\(digest.memoryMilestoneCount == 1 ? "" : "s") were gently marked."
            }
            let body = "\(entries.count) memories spread across the week, with \(digest.photoCount) photo\(digest.photoCount == 1 ? "" : "s") and \(digest.textCount) note\(digest.textCount == 1 ? "" : "s") tucked in."
            let extra = sections.isEmpty ? "" : " " + sections.joined(separator: "; ") + "."
            let ending: String
            if firstNoteSnippet.isEmpty {
                ending = "They can stay quiet and still be kept."
            } else {
                ending = "A moment like \"\(firstNoteSnippet)\" stays safely here."
            }
            return "\(header) \(body)\(extra) \(ending)"
        }
    }

    private func makeRichChineseExpandedText(
        density: WeeklyLetterDensity,
        digest: WeeklyDigest,
        entries: [MemoryEntry],
        firstNoteSnippet: String
    ) -> String {
        var sections: [String] = []
        let growthSummary = makeDigestGrowthMilestoneSummaryChinese(digest.milestones)

        if digest.growthRecordCount > 0 {
            sections.append("\(digest.growthRecordCount) 条成长记录")
        }

        if !digest.firstTasteTags.isEmpty {
            let tagList = digest.firstTasteTags.prefix(3).joined(separator: "、")
            sections.append("新的尝试：\(tagList)")
        }

        if let growthSummary {
            sections.append(growthSummary)
        }

        switch density {
        case .silent:
            if let growthSummary {
                return "这一周只留下一条记忆，安静收好。\(growthSummary)。"
            }
            return "这一周只留下一条记忆，安静收好。"
        case .normal:
            var parts = ["这一周留下了 \(entries.count) 条记忆"]
            if digest.photoCount > 0 {
                parts.append("\(digest.photoCount) 张照片")
            }
            if digest.textCount > 0 {
                parts.append("\(digest.textCount) 段文字")
            }
            parts.append(contentsOf: sections)
            return "\(parts.joined(separator: "，"))。几件小事安静地留了下来，时间也在这些片刻里慢慢往前。"
        case .dense:
            var prefix = "这一周比平时更满一些。"
            if digest.memoryMilestoneCount > 0 {
                prefix += " 其中有 \(digest.memoryMilestoneCount) 个小小的星标。"
            }

            let middle = "照片和文字让这一页更厚了一点，\(entries.count) 条记忆慢慢铺开。"
            let extra = sections.isEmpty ? "" : sections.joined(separator: "，") + "。"
            let ending: String
            if firstNoteSnippet.isEmpty {
                ending = "它们不需要被张扬，只要在翻到这里时能被重新看见。"
            } else {
                ending = "像\u{201C}\(firstNoteSnippet)\u{201D}这样的片刻，也被稳稳留了下来。"
            }
            return "\(prefix)\(middle)\(extra)\(ending)"
        }
    }

    private func buildSourceSignature(digest: WeeklyDigest) -> String {
        let memoryHash = digest.memories.map(\.id.uuidString).sorted().joined(separator: ",")
        let milestoneHash = digest.milestones.map(\.id.uuidString).sorted().joined(separator: ",")
        let growthHash = "\(digest.growthRecordCount)"
        let tasteHash = digest.firstTasteTags.joined(separator: ",")
        return "\(memoryHash)|\(milestoneHash)|\(growthHash)|\(tasteHash)"
    }

    private func makeDigestGrowthMilestoneSummaryEnglish(_ milestones: [DigestGrowthMilestone]) -> String? {
        guard !milestones.isEmpty else { return nil }
        let titles = milestones.map(\.title).prefix(3).joined(separator: ", ")
        let count = milestones.count
        if count == 1 {
            return "A growth milestone reached: \(titles)"
        }
        return "\(count) growth milestones reached: \(titles)"
    }

    private func makeDigestGrowthMilestoneSummaryChinese(_ milestones: [DigestGrowthMilestone]) -> String? {
        guard !milestones.isEmpty else { return nil }
        let titles = milestones.map(\.title).prefix(3).joined(separator: "、")
        let count = milestones.count
        return "本周宝宝达成了 \(count) 个成长里程碑：\(titles)"
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
                maxLength = 100
            case .normal:
                maxLength = 200
            case .dense:
                maxLength = 350
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
