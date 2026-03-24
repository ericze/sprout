import Foundation

enum MilkTab: String, CaseIterable, Identifiable {
    case nursing
    case bottle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nursing:
            "亲喂计时"
        case .bottle:
            "瓶喂记录"
        }
    }
}

enum NursingSide: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left:
            "左"
        case .right:
            "右"
        }
    }

    var badge: String {
        switch self {
        case .left:
            "L"
        case .right:
            "R"
        }
    }
}

struct FeedingDraftState {
    static let presets = [90, 120, 150, 180]
    static let bottleMinimum = 0
    static let bottleMaximum = 300
    static let bottleStep = 10

    var selectedTab: MilkTab = .nursing
    var leftAccumulatedSeconds: Int = 0
    var rightAccumulatedSeconds: Int = 0
    var activeSide: NursingSide?
    var activeStartDate: Date?
    var bottleAmountMl: Int = 0

    var selectedBottlePreset: Int? {
        Self.presets.contains(bottleAmountMl) ? bottleAmountMl : nil
    }

    mutating func selectTab(_ tab: MilkTab) {
        selectedTab = tab
    }

    mutating func tapNursing(side: NursingSide, now: Date) {
        if activeSide == side {
            pauseActiveSide(now: now)
            return
        }

        pauseActiveSide(now: now)
        activeSide = side
        activeStartDate = now
    }

    mutating func pauseActiveSide(now: Date) {
        guard let side = activeSide, let start = activeStartDate else { return }

        let delta = max(0, Int(now.timeIntervalSince(start)))
        switch side {
        case .left:
            leftAccumulatedSeconds += delta
        case .right:
            rightAccumulatedSeconds += delta
        }

        activeSide = nil
        activeStartDate = nil
    }

    func displayedSeconds(for side: NursingSide, now: Date) -> Int {
        let baseSeconds: Int
        switch side {
        case .left:
            baseSeconds = leftAccumulatedSeconds
        case .right:
            baseSeconds = rightAccumulatedSeconds
        }

        guard activeSide == side, let start = activeStartDate else {
            return baseSeconds
        }

        return baseSeconds + max(0, Int(now.timeIntervalSince(start)))
    }

    func totalNursingSeconds(now: Date) -> Int {
        displayedSeconds(for: .left, now: now) + displayedSeconds(for: .right, now: now)
    }

    func canSubmit(now: Date) -> Bool {
        totalNursingSeconds(now: now) > 0 || bottleAmountMl > 0
    }

    func submitButtonTitle(now: Date) -> String {
        let totalNursingSeconds = totalNursingSeconds(now: now)
        let totalMinutes = floorMinutes(totalNursingSeconds)

        if totalNursingSeconds > 0, bottleAmountMl > 0 {
            return "记录 \(totalMinutes)分钟亲喂 + \(bottleAmountMl)ml 瓶喂"
        }

        if totalNursingSeconds > 0 {
            return "记录 \(totalMinutes)分钟亲喂"
        }

        if bottleAmountMl > 0 {
            return "记录 \(bottleAmountMl)ml 瓶喂"
        }

        return "完成记录"
    }

    mutating func selectBottlePreset(_ preset: Int) {
        bottleAmountMl = min(max(preset, Self.bottleMinimum), Self.bottleMaximum)
    }

    mutating func increaseBottle() {
        bottleAmountMl = min(bottleAmountMl + Self.bottleStep, Self.bottleMaximum)
    }

    mutating func decreaseBottle() {
        bottleAmountMl = max(bottleAmountMl - Self.bottleStep, Self.bottleMinimum)
    }

    mutating func reset() {
        self = FeedingDraftState()
    }

    func floorMinutes(_ seconds: Int) -> Int {
        max(0, seconds / 60)
    }
}
