import XCTest
@testable import CCOverlay

final class CodexOAuthServiceTests: XCTestCase {
    func testRejectsResponseWithoutPrimaryRateLimit() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "plan_type": "pro",
            "credits": ["has_credits": true],
        ])

        XCTAssertThrowsError(try CodexOAuthService.parseUsageResponse(data)) { error in
            guard case CodexOAuthService.OAuthError.missingPrimaryRateLimit = error else {
                return XCTFail("Expected missing primary rate limit, got \(error)")
            }
        }
    }

    func testParsesNumericStringsWithoutTreatingThemAsMissingUsage() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "plan_type": "pro",
            "rate_limit": [
                "primary_window": [
                    "used_percent": "29",
                    "limit_window_seconds": "18000",
                    "reset_after_seconds": "3600",
                    "reset_at": "1700003600",
                ],
            ],
        ])

        let usage = try CodexOAuthService.parseUsageResponse(data)

        XCTAssertEqual(usage.primaryWindow?.usedPercent, 29)
        XCTAssertEqual(usage.primaryWindow?.limitWindowSeconds, 18_000)
    }

    func testRejectsPrimaryRateLimitWithoutWindowDuration() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "rate_limit": [
                "primary_window": [
                    "used_percent": 29,
                    "reset_at": 1_700_003_600,
                ],
            ],
        ])

        XCTAssertThrowsError(try CodexOAuthService.parseUsageResponse(data))
    }
}
