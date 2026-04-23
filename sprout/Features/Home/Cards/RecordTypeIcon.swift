import SwiftUI

struct RecordTypeIcon: View {
    let icon: RecordIcon

    var body: some View {
        Group {
            switch icon {
            case .milk:
                MilkBottleIcon(color: AppTheme.Colors.primaryText)
                    .frame(width: 17, height: 17)
            case .food:
                FoodSolidsIcon(color: AppTheme.Colors.primaryText)
                    .frame(width: 17, height: 17)
            case .diaper:
                DiaperIcon(color: AppTheme.Colors.primaryText)
                    .frame(width: 17, height: 17)
            case .sleep, .height, .weight, .headCircumference:
                Image(systemName: icon.systemName)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.primaryText)
            }
        }
        .frame(width: 40, height: 40)
        .background(AppTheme.Colors.homeTimelineIconBackground)
        .clipShape(Circle())
    }
}
