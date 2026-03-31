import SwiftData
import SwiftUI
import UIKit

enum AppTheme {
    enum Colors {
        static let background = Color.dynamic(light: 0xF7F4EE, dark: 0x1C1A18)
        static let cardBackground = Color.dynamic(light: 0xFFFFFF, dark: 0x2A2724)
        static let primaryText = Color.dynamic(light: 0x3A342F, dark: 0xEFEAE0)
        static let accent = Color(hex: 0x8FAE9B)
        static let sageGreen = accent
        static let highlight = Color(hex: 0xD89A7A)
        static let divider = primaryText.opacity(0.08)
        static let floatingMaterial = Color.dynamic(light: 0xFFFFFF, dark: 0x2A2724).opacity(0.94)
        static let floatingBarBackground = Color.dynamic(light: 0xFFFFFF, dark: 0x2A2724).opacity(0.95)
        static let floatingHintBackground = Color.dynamic(light: 0xFFFFFF, dark: 0x2A2724).opacity(0.96)
        static let secondaryText = primaryText.opacity(0.6)
        static let tertiaryText = primaryText.opacity(0.4)
        static let iconBackground = accent.opacity(0.14)
        static let homeTimelineIconBackground = sageGreen.opacity(0.15)
    }

    enum Typography {
        static let navSelected = Font.system(size: 18, weight: .semibold, design: .default)
        static let nav = Font.system(size: 18, weight: .medium, design: .default)
        static let headerDate = Font.system(size: 30, weight: .semibold, design: .default)
        static let headerMeta = Font.system(size: 15, weight: .medium, design: .default)
        static let cardTitle = Font.system(size: 17, weight: .semibold, design: .default)
        static let cardBody = Font.system(size: 15, weight: .regular, design: .default)
        static let meta = Font.system(size: 14, weight: .regular, design: .default)
        static let floatingLabel = Font.system(size: 12, weight: .medium, design: .default)
        static let floatingHint = Font.system(size: 11, weight: .medium, design: .default)
        static let sheetTitle = Font.system(size: 21, weight: .semibold, design: .default)
        static let sheetBody = Font.system(size: 16, weight: .regular, design: .default)
        static let primaryButton = Font.system(size: 17, weight: .semibold, design: .default)
    }

    enum Radius {
        static let card: CGFloat = 24
        static let capsule: CGFloat = 999
        static let sheetCard: CGFloat = 20
        static let chip: CGFloat = 18
        static let image: CGFloat = 28
    }

    enum Spacing {
        static let screenHorizontal: CGFloat = 20
        static let navigationHorizontal: CGFloat = 24
        static let section: CGFloat = 24
        static let cardGap: CGFloat = 16
        static let floatingGap: CGFloat = 12
        static let floatingBottom: CGFloat = 8
    }

    enum Shadow {
        static let color = Color.black.opacity(0.05)
        static let radius: CGFloat = 10
        static let y: CGFloat = 5
        static let floatingBarColor = Color.black.opacity(0.04)
        static let floatingBarRadius: CGFloat = 15
        static let floatingBarY: CGFloat = 8
        static let hintRadius: CGFloat = 10
        static let hintY: CGFloat = 4
    }

    static let stateAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)
}

enum AppHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func softImpact() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func mediumImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

extension Color {
    fileprivate static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(
            uiColor: UIColor { traits in
                let value = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(hex: value)
            }
        )
    }

    fileprivate init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

enum PreviewContainer {
    static func make() -> ModelContainer {
        let schema = Schema([
            RecordItem.self,
            MemoryEntry.self,
            WeeklyLetter.self,
            BabyProfile.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }
}
