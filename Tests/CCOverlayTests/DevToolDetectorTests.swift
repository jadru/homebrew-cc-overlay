import XCTest
@testable import CCOverlay

final class DevToolDetectorTests: XCTestCase {
    func testCodexAppBundleIdIsWhitelisted() {
        XCTAssertTrue(DevToolDetector.isWhitelisted("com.openai.codex"))
    }

    func testCodexHelperBundleIdIsWhitelisted() {
        XCTAssertTrue(DevToolDetector.isWhitelisted("com.openai.codex.helper"))
    }

    func testNonWhitelistedBundleIdReturnsFalse() {
        XCTAssertFalse(DevToolDetector.isWhitelisted("com.example.random-app"))
    }
}
