import SwiftUI
import UIKit

enum TreasureTheme {
    static let pageBackground = AppTheme.Colors.background
    static let paperWhite = Color.treasureDynamic(light: 0xFCFBF8, dark: 0x2A2724)
    static let textPrimary = AppTheme.Colors.primaryText
    static let textSecondary = Color.treasureDynamic(light: 0x7A736C, dark: 0xB8B0A6)
    static let sageDeep = Color.treasureDynamic(light: 0x5F786A, dark: 0xA7C0B1)
    static let terracottaGlow = Color.treasureDynamic(light: 0xC97C5D, dark: 0xD89A7A).opacity(0.04)

    static let cardRadius: CGFloat = 24
    static let cardSpacing: CGFloat = 24
    static let contentPadding: CGFloat = 16
    static let listHorizontalPadding: CGFloat = 16
    static let listTopPadding: CGFloat = 12
    static let listBottomPadding: CGFloat = 140
    static let mediaAspectRatio: CGFloat = 4.0 / 3.0
    static let floatingButtonBottomInset: CGFloat = 24
    static let floatingButtonHorizontalPadding: CGFloat = 18
    static let floatingButtonVerticalPadding: CGFloat = 12
    static let floatingButtonShadowColor = Color.black.opacity(0.05)
    static let floatingButtonShadowRadius: CGFloat = 10
    static let floatingButtonShadowY: CGFloat = 4
    static let floatingButtonForeground = AppTheme.Colors.sageGreen
}

struct TopRoundedCardShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addQuadCurve(
            to: CGPoint(x: radius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: radius),
            control: CGPoint(x: rect.width, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()

        return path
    }
}

private extension Color {
    static func treasureDynamic(light: UInt32, dark: UInt32) -> Color {
        Color(
            uiColor: UIColor { traits in
                UIColor(treasureHex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

private extension UIColor {
    convenience init(treasureHex: UInt32) {
        let red = CGFloat((treasureHex >> 16) & 0xFF) / 255.0
        let green = CGFloat((treasureHex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(treasureHex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
