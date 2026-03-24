import XCTest
@testable import firstgrowth

final class RecordValidatorTests: XCTestCase {
    private let validator = RecordValidator()

    func testMilkValidationAcceptsBottleOnlyRecord() throws {
        XCTAssertNoThrow(
            try validator.validate(
                type: .milk,
                value: 120,
                subType: nil,
                tags: nil,
                note: nil,
                imageURL: nil
            )
        )
    }

    func testMilkValidationAcceptsNursingOnlyRecord() throws {
        XCTAssertNoThrow(
            try validator.validate(
                type: .milk,
                value: nil,
                leftNursingSeconds: 8 * 60,
                rightNursingSeconds: 5 * 60,
                subType: nil,
                tags: nil,
                note: nil,
                imageURL: nil
            )
        )
    }

    func testMilkValidationAcceptsMixedRecord() throws {
        XCTAssertNoThrow(
            try validator.validate(
                type: .milk,
                value: 90,
                leftNursingSeconds: 6 * 60,
                rightNursingSeconds: 0,
                subType: nil,
                tags: nil,
                note: nil,
                imageURL: nil
            )
        )
    }

    func testMilkValidationRejectsEmptyRecord() {
        XCTAssertThrowsError(
            try validator.validate(
                type: .milk,
                value: nil,
                leftNursingSeconds: 0,
                rightNursingSeconds: 0,
                subType: nil,
                tags: nil,
                note: nil,
                imageURL: nil
            )
        ) { error in
            XCTAssertEqual(error as? RecordValidationError, .missingPositiveValue(.milk))
        }
    }

    func testHeightValidationAcceptsPositiveValue() throws {
        XCTAssertNoThrow(
            try validator.validate(
                type: .height,
                value: 75.2,
                subType: nil,
                tags: nil,
                note: nil,
                imageURL: nil
            )
        )
    }

    func testDiaperValidationRejectsUnknownSubtype() {
        XCTAssertThrowsError(
            try validator.validate(
                type: .diaper,
                value: nil,
                subType: "wet",
                tags: nil,
                note: nil,
                imageURL: nil
            )
        ) { error in
            XCTAssertEqual(error as? RecordValidationError, .invalidDiaperSubtype("wet"))
        }
    }

    func testFoodValidationRejectsEmptyRecord() {
        XCTAssertThrowsError(
            try validator.validate(
                type: .food,
                value: nil,
                subType: nil,
                tags: nil,
                note: nil,
                imageURL: nil
            )
        ) { error in
            XCTAssertEqual(error as? RecordValidationError, .emptyFood)
        }
    }
}
