import XCTest
@testable import sprout

final class PaywallContentTests: XCTestCase {
    func test_policyLinks_areNotExampleDotCom() {
        XCTAssertNotEqual(PaywallContent.termsURL.host(), "example.com")
        XCTAssertNotEqual(PaywallContent.privacyURL.host(), "example.com")
    }

    func test_policyLinks_pointToProjectLegalDocs() {
        XCTAssertEqual(PaywallContent.termsURL.scheme, "https")
        XCTAssertEqual(PaywallContent.privacyURL.scheme, "https")
        XCTAssertTrue(PaywallContent.termsURL.path.contains("terms-of-service"))
        XCTAssertTrue(PaywallContent.privacyURL.path.contains("privacy-policy"))
    }

    func test_unreleasedCapabilities_areNotSoldAsPrimaryPaywallPromises() {
        let unreleasedCapabilities: Set<ProCapability> = [
            .multiBaby,
            .familyGroup,
            .cloudSync,
            .aiAssistant,
        ]

        XCTAssertTrue(PaywallContent.promotedCapabilities.isDisjoint(with: unreleasedCapabilities))
        XCTAssertFalse(PaywallContent.isPurchaseEnabled)
    }
}
