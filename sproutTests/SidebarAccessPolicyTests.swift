import Foundation
import Testing
@testable import sprout

@MainActor
struct SidebarAccessPolicyTests {
    @Test("free users see paywall instead of navigating to cloud sync")
    func freeUserCloudSyncShowsPaywall() {
        let decision = SidebarAccessPolicy.decision(
            for: SidebarIndexItem.items.first { $0.id == "cloudSync" },
            subscriptionStatus: .notSubscribed
        )

        #expect(decision == .showPaywall)
    }

    @Test("free users see paywall instead of navigating to family group")
    func freeUserFamilyGroupShowsPaywall() {
        let decision = SidebarAccessPolicy.decision(
            for: SidebarIndexItem.items.first { $0.id == "familyGroup" },
            subscriptionStatus: .notSubscribed
        )

        #expect(decision == .showPaywall)
    }

    @Test("pro users navigate directly to cloud sync")
    func proUserCloudSyncNavigatesDirectly() {
        let decision = SidebarAccessPolicy.decision(
            for: SidebarIndexItem.items.first { $0.id == "cloudSync" },
            subscriptionStatus: .subscribed(
                productID: ProductID.monthly,
                expiration: Date(timeIntervalSince1970: 1_711_000_000)
            )
        )

        #expect(decision == .navigate(.cloudSync))
    }

    @Test("expired users see paywall instead of navigating to family group")
    func expiredUserFamilyGroupShowsPaywall() {
        let decision = SidebarAccessPolicy.decision(
            for: SidebarIndexItem.items.first { $0.id == "familyGroup" },
            subscriptionStatus: .expired(gracePeriodEnds: Date(timeIntervalSince1970: 1_711_000_000))
        )

        #expect(decision == .showPaywall)
    }
}
