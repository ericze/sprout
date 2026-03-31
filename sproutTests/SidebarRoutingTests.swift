import Testing
@testable import sprout

struct SidebarRoutingTests {

    @Test("items count is 4")
    func testItemCount() {
        #expect(SidebarIndexItem.items.count == 4)
    }

    @Test("Pro items are correctly marked")
    func testProFlags() {
        let proItems = SidebarIndexItem.items.filter(\.isPro)
        #expect(proItems.count == 2)
        #expect(proItems.map(\.id).sorted() == ["cloud", "family"])
    }

    @Test("non-Pro items have valid routes")
    func testNonProRoutes() {
        let nonPro = SidebarIndexItem.items.filter { !$0.isPro }
        #expect(nonPro.count == 2)
        for item in nonPro {
            #expect(item.route != nil)
        }
    }

    @Test("Pro items have nil routes")
    func testProNilRoutes() {
        let proItems = SidebarIndexItem.items.filter(\.isPro)
        for item in proItems {
            #expect(item.route == nil)
        }
    }

    @Test("rhythm item is removed")
    func testRhythmRemoved() {
        let ids = SidebarIndexItem.items.map(\.id)
        #expect(!ids.contains("rhythm"))
    }
}
