import XCTest
@testable import CCOverlay

final class UsageDecisionEngineTests: XCTestCase {
    func testRecommendsBestProviderWhenHeadroomIsHealthy() {
        let decision = UsageDecisionEngine.recommend(from: [
            data(.claudeCode, remaining: 68),
            data(.codex, remaining: 82),
        ])

        XCTAssertEqual(decision.kind, .run)
        XCTAssertEqual(decision.recommendedProvider, .codex)
    }

    func testRecommendsSwitchWhenCurrentProviderIsConstrained() {
        let decision = UsageDecisionEngine.recommend(from: [
            data(.claudeCode, remaining: 14),
            data(.codex, remaining: 71),
        ], currentProvider: .claudeCode)

        XCTAssertEqual(decision.kind, .switchProvider)
        XCTAssertEqual(decision.recommendedProvider, .codex)
    }

    func testDoesNotRecommendSwitchWhenUserAlreadyRunsBestProvider() {
        let decision = UsageDecisionEngine.recommend(from: [
            data(.claudeCode, remaining: 14),
            data(.codex, remaining: 71),
        ], currentProvider: .codex)

        XCTAssertEqual(decision.kind, .run)
        XCTAssertEqual(decision.recommendedProvider, .codex)
    }

    func testRecommendsWaitWhenEveryProviderIsNearLimit() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let reset = now.addingTimeInterval(900)
        let decision = UsageDecisionEngine.recommend(
            from: [
                data(.claudeCode, remaining: 7, reset: reset),
                data(.codex, remaining: 4, reset: now.addingTimeInterval(1_800)),
            ],
            now: now
        )

        XCTAssertEqual(decision.kind, .wait)
        XCTAssertEqual(decision.resetAt, reset)
    }

    func testIgnoresUnsupportedBucketsWhenCalculatingHeadroom() {
        let item = ProviderUsageData(
            provider: .codex,
            isAvailable: true,
            usedPercentage: 20,
            remainingPercentage: 80,
            primaryWindowLabel: "5h",
            rateLimitBuckets: [RateBucket(label: "Spark", utilization: 100)]
        )

        XCTAssertEqual(UsageDecisionEngine.headroom(for: item), 80)
    }

    private func data(
        _ provider: CLIProvider,
        remaining: Double,
        reset: Date? = nil
    ) -> ProviderUsageData {
        ProviderUsageData(
            provider: provider,
            isAvailable: true,
            usedPercentage: 100 - remaining,
            remainingPercentage: remaining,
            primaryWindowLabel: "5h",
            resetsAt: reset,
            rateLimitBuckets: [
                RateBucket(label: "5h", utilization: 100 - remaining, resetsAt: reset)
            ]
        )
    }
}
