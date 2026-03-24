import XCTest
@testable import firstgrowth

final class TimelineContentFormatterTests: XCTestCase {
    private let formatter = TimelineContentFormatter()

    func testFormatsStandardRecords() {
        let timestamp = Date(timeIntervalSince1970: 1_710_000_000)

        let bottleFeeding = RecordItem(timestamp: timestamp, type: RecordType.milk.rawValue, value: 120)
        let nursingFeeding = RecordItem(
            timestamp: timestamp,
            type: RecordType.milk.rawValue,
            leftNursingSeconds: 15 * 60,
            rightNursingSeconds: 10 * 60
        )
        let mixedFeeding = RecordItem(
            timestamp: timestamp,
            type: RecordType.milk.rawValue,
            value: 60,
            leftNursingSeconds: 5 * 60 + 59,
            rightNursingSeconds: 2 * 60 + 1
        )
        let diaper = RecordItem(timestamp: timestamp, type: RecordType.diaper.rawValue, subType: DiaperSubtype.both.rawValue)
        let sleep = RecordItem(timestamp: timestamp, type: RecordType.sleep.rawValue, value: 6_120)

        XCTAssertEqual(formatter.makeDisplayItem(from: bottleFeeding)?.title, "120ml 瓶喂")
        XCTAssertEqual(formatter.makeDisplayItem(from: nursingFeeding)?.title, "亲喂 25分钟")
        XCTAssertEqual(formatter.makeDisplayItem(from: nursingFeeding)?.subtitle, "左 15m · 右 10m")
        XCTAssertEqual(formatter.makeDisplayItem(from: mixedFeeding)?.title, "亲喂 8分钟 + 60ml 瓶喂")
        XCTAssertEqual(formatter.makeDisplayItem(from: mixedFeeding)?.subtitle, "左 5m · 右 2m")
        XCTAssertEqual(formatter.makeDisplayItem(from: diaper)?.title, "尿布：都有")
        XCTAssertEqual(formatter.makeDisplayItem(from: sleep)?.title, "睡了 1小时42分")
    }

    func testFeedingFormatterFloorsMinutesConsistently() {
        let shortNursing = RecordItem(
            timestamp: .now,
            type: RecordType.milk.rawValue,
            leftNursingSeconds: 59,
            rightNursingSeconds: 0
        )

        let displayItem = formatter.makeDisplayItem(from: shortNursing)

        XCTAssertEqual(displayItem?.title, "亲喂 0分钟")
        XCTAssertNil(displayItem?.subtitle)
    }

    func testFallsBackWhenFoodImagePathIsInvalid() {
        let food = RecordItem(
            timestamp: .now,
            type: RecordType.food.rawValue,
            imageURL: "/tmp/does-not-exist.jpg",
            tags: ["南瓜", "米粉"],
            note: "今天一直在扔勺子"
        )

        let displayItem = formatter.makeDisplayItem(from: food)

        XCTAssertEqual(displayItem?.cardStyle, .standard)
        XCTAssertNil(displayItem?.imagePath)
        XCTAssertEqual(displayItem?.title, "吃了南瓜、米粉 / 今天一直在扔勺子")
    }

    func testUsesPhotoCardWhenFoodImageExists() throws {
        let imagePath = try FoodPhotoStorage.storeImageData(Data(repeating: 0xFF, count: 8))
        defer { FoodPhotoStorage.removeImage(at: imagePath) }

        let food = RecordItem(
            timestamp: .now,
            type: RecordType.food.rawValue,
            imageURL: imagePath,
            tags: ["香蕉"],
            note: nil
        )

        let displayItem = formatter.makeDisplayItem(from: food)

        XCTAssertEqual(displayItem?.cardStyle, .foodPhoto)
        XCTAssertEqual(displayItem?.imagePath, imagePath)
    }
}
