import SwiftUI

struct TreasureTimelineList: View {
    let dataState: TreasureDataState
    let items: [TreasureTimelineItem]
    let errorMessage: String?
    let onTapWeeklyLetter: (UUID) -> Void

    var body: some View {
        if items.isEmpty {
            TreasureEmptyState(dataState: dataState, errorMessage: errorMessage)
        } else {
            LazyVStack(alignment: .leading, spacing: TreasureTheme.cardSpacing) {
                ForEach(items) { item in
                    card(for: item)
                        .id(item.id)
                }
            }
        }
    }

    @ViewBuilder
    private func card(for item: TreasureTimelineItem) -> some View {
        switch item.type {
        case .memory, .milestone, .growthMilestone:
            TreasureMemoryCard(item: item)
        case .weeklyLetterSilent, .weeklyLetterNormal, .weeklyLetterDense:
            TreasureWeeklyLetterCard(item: item, onTap: {
                onTapWeeklyLetter(item.id)
            })
        }
    }
}
