import XCTest
@testable import CCOverlay

final class DurationFormattingTests: XCTestCase {
    func testDurationAtLeastOneDayUsesDaysAndHours() {
        XCTAssertEqual(DurationFormatting.compactReset(166 * 60 * 60), "6d 22h")
    }

    func testDurationBelowOneDayUsesHoursAndMinutes() {
        XCTAssertEqual(DurationFormatting.compactReset(23 * 60 * 60 + 5 * 60), "23h 05m")
    }

    func testDurationAtExactlyOneDayUsesDaysAndHours() {
        XCTAssertEqual(DurationFormatting.compactReset(24 * 60 * 60), "1d 0h")
    }

    func testDurationBelowOneHourStillUsesHoursAndMinutes() {
        XCTAssertEqual(DurationFormatting.compactReset(45 * 60), "0h 45m")
    }
}
