import XCTest
@testable import CCOverlay

final class ProviderServiceNormalizationTests: XCTestCase {
    func testClaudeDetectedPlanOverridesFallbackLimit() {
        let limit = ClaudeCodeProviderService.resolvedWeightedCostLimit(
            planIdentifier: "max_5",
            fallbackLimit: PlanTier.pro.weightedCostLimit
        )

        XCTAssertEqual(limit, PlanTier.max5.weightedCostLimit)
    }

    func testPlanTierParsesUsageIdentifiers() {
        XCTAssertEqual(PlanTier.fromUsageIdentifier("max_5"), .max5)
        XCTAssertEqual(PlanTier.fromUsageIdentifier("max_20"), .max20)
        XCTAssertEqual(PlanTier.fromUsageIdentifier("enterprise_tier"), .enterprise)
        XCTAssertEqual(PlanTier.fromUsageIdentifier("  pro  "), .pro)
        XCTAssertNil(PlanTier.fromUsageIdentifier("starter"))
    }

    func testClaudeEstimatedPlanNameIsMarked() {
        let name = ClaudeCodeProviderService.resolvedPlanName(
            planIdentifier: "max_5",
            hasAPIData: false
        )

        XCTAssertEqual(name, "Max ($100/mo) (est.)")
    }

    func testClaudeAPIBackedPlanNameIsUnchanged() {
        let name = ClaudeCodeProviderService.resolvedPlanName(
            planIdentifier: "max_5",
            hasAPIData: true
        )

        XCTAssertEqual(name, "Max ($100/mo)")
    }

    func testClaudePredictsSessionMinutesRemaining() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = SessionUsage(
            id: "session-1",
            model: "claude-sonnet",
            tokenUsage: TokenUsage(
                inputTokens: 1000,
                outputTokens: 0,
                cacheCreationInputTokens: 0,
                cacheReadInputTokens: 0
            ),
            messageCount: 3,
            firstTimestamp: now.addingTimeInterval(-3600),
            lastTimestamp: now
        )
        let aggregated = AggregatedUsage(
            currentSession: session,
            fiveHourWindow: session.tokenUsage,
            dailyTotal: session.tokenUsage,
            allSessions: [session],
            fiveHourCost: .zero,
            dailyCost: .zero
        )

        let prediction = ClaudeCodeProviderService.predictedSessionExhaustion(
            aggregatedUsage: aggregated,
            limit: 3000,
            now: now
        )

        XCTAssertEqual(prediction?.formattedTimeRemaining, "~2h 0m left")
    }

    func testCodexWeeklyWindowUsesOneWeekLabel() {
        let label = CodexProviderService.normalizedWindowLabel(
            windowSeconds: 7 * 24 * 60 * 60,
            fallback: "7d"
        )

        XCTAssertEqual(label, "1w")
    }

    func testCodexSparkLimitUsesFriendlyLabel() {
        let label = CodexProviderService.normalizedAdditionalLimitLabel(
            limitName: "spark_session",
            meteredFeature: "spark"
        )

        XCTAssertEqual(label, "Spark")
    }

    func testCodexEffectiveUsageTracksMostConstrainedWindow() {
        let secondary = CodexOAuthService.RateLimitWindow(
            usedPercent: 42,
            limitWindowSeconds: 7 * 24 * 60 * 60,
            resetAfterSeconds: 1800,
            resetAt: 1
        )
        let spark = CodexOAuthService.AdditionalLimit(
            limitName: "spark_session",
            meteredFeature: "spark",
            primaryWindow: .init(
                usedPercent: 100,
                limitWindowSeconds: 5 * 60 * 60,
                resetAfterSeconds: 1200,
                resetAt: 1
            )
        )

        let effective = CodexProviderService.effectiveUsedPercentage(
            primaryUsedPct: 55,
            secondaryWindow: secondary,
            additionalLimits: [spark]
        )

        XCTAssertEqual(effective, 100)
    }
}
