import Foundation

struct PaywallContent {
    struct Feature: Identifiable, Equatable {
        let capability: ProCapability
        let iconName: String
        let titleKey: String
        let titleEN: String
        let titleZH: String
        let detailKey: String
        let detailEN: String
        let detailZH: String

        var id: ProCapability { capability }
    }

    static let termsURL = URL(string: "https://github.com/ericze/firstGrowth-ios/blob/main/docs/legal/terms-of-service.md")!
    static let privacyURL = URL(string: "https://github.com/ericze/firstGrowth-ios/blob/main/docs/legal/privacy-policy.md")!

    static let promotedCapabilities: Set<ProCapability> = []

    static var isPurchaseEnabled: Bool {
        !promotedCapabilities.isEmpty
    }

    static var promotedFeatures: [Feature] {
        allFeatures.filter { promotedCapabilities.contains($0.capability) }
    }

    static let allFeatures: [Feature] = [
        Feature(
            capability: .multiBaby,
            iconName: "figure.2.and.child",
            titleKey: "paywall.feature.multibaby.title",
            titleEN: "Multi-Baby",
            titleZH: "多宝宝管理",
            detailKey: "paywall.feature.multibaby.detail",
            detailEN: "Track multiple babies",
            detailZH: "记录多个宝宝的成长"
        ),
        Feature(
            capability: .familyGroup,
            iconName: "person.2",
            titleKey: "paywall.feature.family.title",
            titleEN: "Family Group",
            titleZH: "家庭组",
            detailKey: "paywall.feature.family.detail",
            detailEN: "Invite family to co-record",
            detailZH: "邀请家人共同记录"
        ),
        Feature(
            capability: .cloudSync,
            iconName: "cloud",
            titleKey: "paywall.feature.cloud.title",
            titleEN: "Cloud Sync",
            titleZH: "云端同步",
            detailKey: "paywall.feature.cloud.detail",
            detailEN: "Secure data backup",
            detailZH: "数据安全备份"
        ),
        Feature(
            capability: .aiAssistant,
            iconName: "brain",
            titleKey: "paywall.feature.ai.title",
            titleEN: "AI Assistant",
            titleZH: "AI 智能助手",
            detailKey: "paywall.feature.ai.detail",
            detailEN: "Food advice, analysis & reports",
            detailZH: "辅食建议、分析、周报"
        ),
    ]
}
