import XCTest
@testable import CCOverlay

final class UsageDecisionEngineTests: XCTestCase {
    func testRecommendsBestProviderWhenHeadroomIsHealthy() {
        let now = Date()
        let decision = UsageDecisionEngine.recommend(from: [
            data(.claudeCode, remaining: 68, refreshedAt: now),
            data(.codex, remaining: 82, refreshedAt: now),
        ], now: now)

        XCTAssertEqual(decision.kind, .run)
        XCTAssertEqual(decision.recommendedProvider, .codex)
    }

    func testCodexFirstPrefersSafeCodexEvenWhenClaudeHasMoreHeadroom() {
        let now = Date()
        let decision = UsageDecisionEngine.recommend(
            from: [
                data(.claudeCode, remaining: 90, refreshedAt: now),
                data(.codex, remaining: 55, refreshedAt: now),
            ],
            providerPriority: .codexFirst,
            now: now
        )

        XCTAssertEqual(decision.kind, .run)
        XCTAssertEqual(decision.recommendedProvider, .codex)
        XCTAssertTrue(decision.reasons.contains { $0.contains("Codex first") })
    }

    func testMostHeadroomStrategyCanPreferClaude() {
        let now = Date()
        let decision = UsageDecisionEngine.recommend(
            from: [
                data(.claudeCode, remaining: 90, refreshedAt: now),
                data(.codex, remaining: 55, refreshedAt: now),
            ],
            providerPriority: .mostHeadroom,
            now: now
        )

        XCTAssertEqual(decision.recommendedProvider, .claudeCode)
    }

    func testCodexFirstFallsBackWhenCodexDoesNotSafelyFit() {
        let now = Date()
        let decision = UsageDecisionEngine.recommend(
            from: [
                data(.claudeCode, remaining: 80, refreshedAt: now),
                data(.codex, remaining: 20, refreshedAt: now),
            ],
            providerPriority: .codexFirst,
            now: now
        )

        XCTAssertEqual(decision.recommendedProvider, .claudeCode)
    }

    func testRecommendsSwitchWhenCurrentProviderIsConstrained() {
        let now = Date()
        let decision = UsageDecisionEngine.recommend(from: [
            data(.claudeCode, remaining: 14, refreshedAt: now),
            data(.codex, remaining: 71, refreshedAt: now),
        ], currentProvider: .claudeCode, now: now)

        XCTAssertEqual(decision.kind, .switchProvider)
        XCTAssertEqual(decision.recommendedProvider, .codex)
    }

    func testDoesNotRecommendSwitchWhenUserAlreadyRunsBestProvider() {
        let now = Date()
        let decision = UsageDecisionEngine.recommend(from: [
            data(.claudeCode, remaining: 14, refreshedAt: now),
            data(.codex, remaining: 71, refreshedAt: now),
        ], currentProvider: .codex, now: now)

        XCTAssertEqual(decision.kind, .run)
        XCTAssertEqual(decision.recommendedProvider, .codex)
    }

    func testRecommendsWaitWhenEveryProviderIsNearLimit() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let reset = now.addingTimeInterval(900)
        let decision = UsageDecisionEngine.recommend(
            from: [
                data(.claudeCode, remaining: 7, reset: reset, refreshedAt: now),
                data(.codex, remaining: 4, reset: now.addingTimeInterval(1_800), refreshedAt: now),
            ],
            now: now
        )

        XCTAssertEqual(decision.kind, .wait)
        XCTAssertEqual(decision.resetAt, reset)
    }

    func testRecommendsBankedResetInsteadOfWaitingWhenCodexResetIsApplicable() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let decision = UsageDecisionEngine.recommend(
            from: [
                data(.claudeCode, remaining: 7, refreshedAt: now),
                data(
                    .codex,
                    remaining: 0,
                    refreshedAt: now,
                    resetCreditsAvailable: 2,
                    resetCreditsApplicable: 1
                ),
            ],
            now: now
        )

        XCTAssertEqual(decision.kind, .useReset)
        XCTAssertEqual(decision.recommendedProvider, .codex)
        XCTAssertTrue(decision.detail.contains("1 banked reset"))
    }

    func testConservePolicyPreservesFinalBankedReset() {
        let now = Date()
        let decision = UsageDecisionEngine.recommend(
            from: [
                data(
                    .codex,
                    remaining: 0,
                    refreshedAt: now,
                    resetCreditsAvailable: 1,
                    resetCreditsApplicable: 1
                ),
            ],
            fullResetPolicy: .conserveLast,
            now: now
        )

        XCTAssertEqual(decision.kind, .wait)
        XCTAssertTrue(decision.reasons.contains { $0.contains("preserved") })
    }

    func testExpiringResetOverridesConservePolicyWhenCodexIsAtLimit() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let expiration = now.addingTimeInterval(6 * 60 * 60)
        let decision = UsageDecisionEngine.recommend(
            from: [
                data(
                    .codex,
                    remaining: 0,
                    refreshedAt: now,
                    resetCreditsAvailable: 1,
                    resetCreditsApplicable: 1,
                    resetCreditExpirations: [expiration]
                ),
            ],
            fullResetPolicy: .conserveLast,
            now: now
        )

        XCTAssertEqual(decision.kind, .useReset)
        XCTAssertTrue(decision.detail.contains("expires in"))
    }

    func testExpiredResetIsNotRecommended() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let decision = UsageDecisionEngine.recommend(
            from: [
                data(
                    .codex,
                    remaining: 0,
                    refreshedAt: now,
                    resetCreditsAvailable: 1,
                    resetCreditsApplicable: 1,
                    resetCreditExpirations: [now.addingTimeInterval(-1)]
                ),
            ],
            now: now
        )

        XCTAssertEqual(decision.kind, .wait)
    }

    func testPreferResetPolicyUsesResetBeforeHealthyAlternative() {
        let now = Date()
        let decision = UsageDecisionEngine.recommend(
            from: [
                data(.claudeCode, remaining: 80, refreshedAt: now),
                data(
                    .codex,
                    remaining: 0,
                    refreshedAt: now,
                    resetCreditsAvailable: 2,
                    resetCreditsApplicable: 1
                ),
            ],
            fullResetPolicy: .preferReset,
            now: now
        )

        XCTAssertEqual(decision.kind, .useReset)
        XCTAssertEqual(decision.recommendedHeadroom, 100)
        XCTAssertFalse(decision.reasons.isEmpty)
    }

    func testRequiresRefreshWhenAllProviderDataIsStale() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let decision = UsageDecisionEngine.recommend(
            from: [data(.codex, remaining: 80, refreshedAt: now.addingTimeInterval(-600))],
            staleAfter: 120,
            now: now
        )

        XCTAssertEqual(decision.kind, .refresh)
        XCTAssertEqual(decision.confidence, .low)
        XCTAssertEqual(decision.dataQuality, .stale)
    }

    func testStabilizerRequiresTwoFreshSnapshotsForNonUrgentChange() {
        let stabilizer = UsageDecisionStabilizer()
        let first = UsageDecision(
            kind: .run,
            title: "Run on Codex",
            detail: "Healthy",
            recommendedProvider: .codex,
            resetAt: nil
        )
        let changed = UsageDecision(
            kind: .switchProvider,
            title: "Switch to Claude Code",
            detail: "More room",
            recommendedProvider: .claudeCode,
            resetAt: nil
        )
        let start = Date()

        XCTAssertEqual(stabilizer.resolve(candidate: first, snapshotVersion: start).kind, .run)
        XCTAssertEqual(stabilizer.resolve(candidate: changed, snapshotVersion: start.addingTimeInterval(60)).kind, .run)
        XCTAssertEqual(stabilizer.resolve(candidate: changed, snapshotVersion: start.addingTimeInterval(120)).kind, .switchProvider)
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
        reset: Date? = nil,
        refreshedAt: Date? = Date(),
        resetCreditsAvailable: Int = 0,
        resetCreditsApplicable: Int = 0,
        resetCreditExpirations: [Date] = []
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
            ],
            creditsInfo: provider == .codex
                ? CreditsDisplayInfo(
                    planType: "Pro",
                    hasCredits: false,
                    unlimited: false,
                    balance: nil,
                    extraUsageEnabled: false,
                    resetCreditsAvailable: resetCreditsAvailable,
                    resetCreditsApplicable: resetCreditsApplicable,
                    resetCreditExpirations: resetCreditExpirations
                )
                : nil,
            lastRefresh: refreshedAt
        )
    }
}
