import Testing
@testable import sprout

@MainActor
struct SidebarRoutingTests {

    @Test("sidebar contains 4 items: language, account, cloudSync, familyGroup")
    func testItemCount() {
        #expect(SidebarIndexItem.items.count == 4)
    }

    @Test("all routes are unique")
    func testAllRoutesUnique() {
        let routes = SidebarIndexItem.items.map(\.route)
        #expect(Set(routes).count == routes.count)
    }

    @Test("expected item IDs are present")
    func testExpectedIDs() {
        let ids = Set(SidebarIndexItem.items.map(\.id))
        #expect(ids.contains("language"))
        #expect(ids.contains("account"))
        #expect(ids.contains("cloudSync"))
        #expect(ids.contains("familyGroup"))
    }

    @Test("removed items are absent")
    func testRemovedItems() {
        let ids = SidebarIndexItem.items.map(\.id)
        #expect(!ids.contains("profile"))
        #expect(!ids.contains("rhythm"))
    }

    @Test("sidebar items reflect the current app language")
    func testSidebarItemsRecalculateForLanguageChanges() {
        let previousOverride = LocalizationService.overrideLanguage

        defer {
            LocalizationService.overrideLanguage = previousOverride
        }

        LocalizationService.override(language: .english)
        let englishTitles = SidebarIndexItem.items.map(\.title)
        let englishDetails = SidebarIndexItem.items.map(\.detail)

        LocalizationService.override(language: .simplifiedChinese)
        let chineseTitles = SidebarIndexItem.items.map(\.title)
        let chineseDetails = SidebarIndexItem.items.map(\.detail)

        #expect(englishTitles != chineseTitles)
        #expect(englishDetails != chineseDetails)
    }

    @Test("language routes to language")
    func testLanguageRoute() {
        let lang = SidebarIndexItem.items.first { $0.id == "language" }
        #expect(lang != nil)
        #expect(lang?.route == .language)
    }

    @Test("account routes to account and is not pro gated")
    func testAccountRoute() {
        let account = SidebarIndexItem.items.first { $0.id == "account" }
        #expect(account != nil)
        #expect(account?.route == .account)
        #expect(account?.isPro == false)
    }

    @Test("cloud sync is available without pro gate in phase 2")
    func testCloudSyncIsNotProGated() {
        let cloudSync = SidebarIndexItem.items.first { $0.id == "cloudSync" }
        #expect(cloudSync != nil)
        #expect(cloudSync?.route == .cloudSync)
        #expect(cloudSync?.isPro == false)
    }
}
