import Foundation

enum GrowthSummaryKind: Equatable {
    case guidance
    case started
    case summary(delta: Double, daysSinceLast: Int, milestoneCountThisMonth: Int)
}

struct GrowthSummary: Equatable {
    let kind: GrowthSummaryKind
    let metric: GrowthMetric
    let latestValue: Double?
    let latestDate: Date?
}

struct GrowthSummaryBuilder {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func build(
        metric: GrowthMetric,
        points: [GrowthPoint],
        milestoneDates: [Date],
        now: Date
    ) -> GrowthSummary {
        let milestoneCountThisMonth = countMilestonesThisMonth(milestoneDates: milestoneDates, now: now)

        guard let latest = points.last else {
            return GrowthSummary(
                kind: .guidance,
                metric: metric,
                latestValue: nil,
                latestDate: nil
            )
        }

        guard points.count >= 2 else {
            return GrowthSummary(
                kind: .started,
                metric: metric,
                latestValue: latest.value,
                latestDate: latest.date
            )
        }

        let previous = points[points.count - 2]
        let delta = rounded(latest.value - previous.value, precision: 0.1)
        let daysSinceLast = max(
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: latest.date),
                to: calendar.startOfDay(for: now)
            ).day ?? 0,
            0
        )

        return GrowthSummary(
            kind: .summary(
                delta: delta,
                daysSinceLast: daysSinceLast,
                milestoneCountThisMonth: milestoneCountThisMonth
            ),
            metric: metric,
            latestValue: latest.value,
            latestDate: latest.date
        )
    }

    private func countMilestonesThisMonth(milestoneDates: [Date], now: Date) -> Int {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        return milestoneDates.filter { $0 >= startOfMonth && $0 <= now }.count
    }

    private func rounded(_ value: Double, precision: Double) -> Double {
        guard precision > 0 else { return value }
        return (value / precision).rounded() * precision
    }
}
