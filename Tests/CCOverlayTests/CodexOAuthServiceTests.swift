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

    func testParsesBankedRateLimitResetCredits() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "rate_limit": [
                "primary_window": [
                    "used_percent": 100,
                    "limit_window_seconds": 18_000,
                    "reset_at": 1_700_003_600,
                ],
            ],
            "rate_limit_reset_credits": [
                "available_count": "2",
                "applicable_available_count": 1,
            ],
        ])

        let usage = try CodexOAuthService.parseUsageResponse(data)

        XCTAssertEqual(
            usage.rateLimitResetCredits,
            .init(availableCount: 2, applicableAvailableCount: 1)
        )
    }

    func testParsesResetCreditExpirationWhenUsageEndpointProvidesDetails() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "rate_limit": [
                "primary_window": [
                    "used_percent": 100,
                    "limit_window_seconds": 18_000,
                    "reset_at": 1_700_003_600,
                ],
            ],
            "rate_limit_reset_credits": [
                "available_count": 1,
                "applicable_available_count": 1,
                "credits": [[
                    "status": "available",
                    "granted_at": 1_783_963_632,
                    "expires_at": 1_786_555_632,
                ]],
            ],
        ])

        let usage = try CodexOAuthService.parseUsageResponse(data)

        XCTAssertEqual(usage.rateLimitResetCredits?.credits.count, 1)
        XCTAssertEqual(
            usage.rateLimitResetCredits?.credits.first?.expiresAt,
            Date(timeIntervalSince1970: 1_786_555_632)
        )
    }

    func testParsesOfficialAppServerResetCreditShape() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "id": 2,
            "result": [
                "rateLimitResetCredits": [
                    "availableCount": 1,
                    "credits": [[
                        "status": "available",
                        "grantedAt": 1_783_963_632,
                        "expiresAt": 1_786_555_632,
                    ]],
                ],
            ],
        ])

        let snapshot = try CodexAppServerService.parseRateLimitResetResponse(data)

        XCTAssertEqual(snapshot.availableCount, 1)
        XCTAssertEqual(snapshot.credits.first?.status, "available")
        XCTAssertEqual(
            snapshot.credits.first?.expiresAt,
            Date(timeIntervalSince1970: 1_786_555_632)
        )
    }

    func testExpiredDetailedResetIsRemovedFromEffectiveCount() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let credits = CodexOAuthService.RateLimitResetCredits(
            availableCount: 1,
            applicableAvailableCount: 1,
            credits: [
                .init(
                    status: "available",
                    grantedAt: nil,
                    expiresAt: now.addingTimeInterval(-1)
                ),
            ]
        )

        XCTAssertEqual(CodexProviderService.effectiveResetCreditCount(credits, now: now), 0)
    }
}
