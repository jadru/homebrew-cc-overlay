import XCTest
@testable import CCOverlay

final class OAuthResponseParserTests: XCTestCase {
    private let parser = OAuthResponseParser()

    func testParsesFullUsagePayload() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "five_hour": [
                "utilization": 42.5,
                "resets_at": "2026-03-10T02:30:00Z",
            ],
            "seven_day": [
                "utilization": 76.0,
                "resets_at": "2026-03-16T00:00:00Z",
            ],
            "seven_day_sonnet": [
                "utilization": 12.0,
                "resets_at": "2026-03-16T00:00:00Z",
            ],
            "extra_usage": [
                "is_enabled": true,
            ],
            "enterprise": [
                "organization_name": "Acme",
                "seat_tier": "premium",
                "organization_limit": [
                    "cap_dollars": 1000,
                    "used_dollars": 250,
                    "period": "monthly",
                    "resets_at": "2026-04-01T00:00:00Z",
                ],
                "seat_tier_limit": [
                    "cap_dollars": 300,
                    "used_dollars": 100,
                    "period": "monthly",
                ],
                "individual_limit": [
                    "cap_dollars": 150,
                    "used_dollars": 90,
                    "period": "monthly",
                ],
            ],
        ]

        let usage = try parser.parseUsageResponse(makeData(payload), fetchedAt: fetchedAt)

        XCTAssertEqual(usage.fiveHour.utilization, 42.5)
        XCTAssertEqual(usage.sevenDay.utilization, 76.0)
        XCTAssertEqual(usage.sevenDaySonnet?.utilization, 12.0)
        XCTAssertTrue(usage.extraUsageEnabled)
        XCTAssertEqual(usage.enterpriseQuota?.organizationName, "Acme")
        XCTAssertEqual(usage.enterpriseQuota?.seatTier, .premium)
        XCTAssertEqual(usage.enterpriseQuota?.organizationLimit.capDollars, 1000)
        XCTAssertEqual(usage.enterpriseQuota?.organizationLimit.usedDollars, 250)
        XCTAssertEqual(usage.fetchedAt, fetchedAt)
        XCTAssertNotNil(usage.fiveHour.resetsAt)
        XCTAssertNotNil(usage.enterpriseQuota?.organizationLimit.resetsAt)
    }

    func testMissingSonnetBucketReturnsNil() throws {
        let payload: [String: Any] = [
            "five_hour": [
                "utilization": 10,
            ],
            "seven_day": [
                "utilization": 20,
            ],
        ]

        let usage = try parser.parseUsageResponse(makeData(payload), fetchedAt: Date())

        XCTAssertNil(usage.sevenDaySonnet)
        XCTAssertEqual(usage.fiveHour.utilization, 10)
        XCTAssertEqual(usage.sevenDay.utilization, 20)
    }

    func testParsesNestedWrapperPayload() throws {
        let payload: [String: Any] = [
            "usage": [
                "five_hour": [
                    "utilization": 55,
                    "resets_at": "2026-03-10T05:00:00Z",
                ],
                "seven_day": [
                    "utilization": 60,
                    "resets_at": "2026-03-17T00:00:00Z",
                ],
                "seven_day_sonnet": [
                    "utilization": 15,
                    "resets_at": "2026-03-17T00:00:00Z",
                ],
            ],
        ]

        let usage = try parser.parseUsageResponse(makeData(payload), fetchedAt: Date())

        XCTAssertEqual(usage.fiveHour.utilization, 55)
        XCTAssertEqual(usage.sevenDay.utilization, 60)
        XCTAssertEqual(usage.sevenDaySonnet?.utilization, 15)
        XCTAssertNotNil(usage.fiveHour.resetsAt)
    }

    func testMalformedPayloadFallsBackToZeroBuckets() throws {
        let payload: [String: Any] = [
            "five_hour": "wrong",
            "seven_day": [
                "utilization": "not-a-number",
                "resets_at": 123,
            ],
            "seven_day_sonnet": NSNull(),
            "enterprise": [
                "organization_name": "Broken",
                "organization_limit": "bad",
                "seat_tier_limit": [:],
                "individual_limit": [
                    "cap_dollars": "19.5",
                    "used_dollars": 4,
                ],
            ],
        ]

        let usage = try parser.parseUsageResponse(makeData(payload), fetchedAt: Date())

        XCTAssertEqual(usage.fiveHour.utilization, 0)
        XCTAssertNil(usage.fiveHour.resetsAt)
        XCTAssertEqual(usage.sevenDay.utilization, 0)
        XCTAssertNil(usage.sevenDay.resetsAt)
        XCTAssertEqual(usage.sevenDaySonnet?.utilization, 0)
        XCTAssertEqual(usage.enterpriseQuota?.organizationLimit.capDollars, 0)
        XCTAssertEqual(usage.enterpriseQuota?.individualLimit.capDollars, 19.5)
        XCTAssertEqual(usage.enterpriseQuota?.individualLimit.usedDollars, 4)
    }

    func testNonDictionaryPayloadThrowsInvalidResponse() throws {
        let data = try JSONSerialization.data(withJSONObject: ["a", "b"])

        XCTAssertThrowsError(try parser.parseUsageResponse(data, fetchedAt: Date())) { error in
            XCTAssertEqual(error as? AnthropicAPIService.APIError, .invalidResponse)
        }
    }

    private func makeData(_ payload: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: payload)
    }
}
