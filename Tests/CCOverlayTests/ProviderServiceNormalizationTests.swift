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

    func testUsageTimelinePrioritizesFiveHourAndSevenDayWindows() {
        let labels = UsageTimelineView.primaryWindowLabels(from: [
            RateBucket(label: "Spark", utilization: 0),
            RateBucket(label: "1w", utilization: 8),
            RateBucket(label: "5h", utilization: 53),
        ])

        XCTAssertEqual(labels, ["5h", "7d"])
    }

    func testUsageTimelineHidesSparkFromAdditionalLimits() {
        let buckets = UsageTimelineView.visibleAdditionalBuckets(from: [
            RateBucket(label: "1w", utilization: 8),
            RateBucket(label: "Spark", utilization: 0),
            RateBucket(label: "Sonnet", utilization: 12),
        ])

        XCTAssertEqual(buckets.map(\.label), ["Sonnet"])
    }

    func testCodexSparkLimitUsesFriendlyLabel() {
        let label = CodexProviderService.normalizedAdditionalLimitLabel(
            limitName: "spark_session",
            meteredFeature: "spark"
        )

        XCTAssertEqual(label, "Spark")
    }

    func testCodexDisplayUsageExpiresAfterReset() {
        let window = CodexOAuthService.RateLimitWindow(
            usedPercent: 100,
            limitWindowSeconds: 5 * 60 * 60,
            resetAfterSeconds: 0,
            resetAt: 1_700_000_000
        )

        XCTAssertEqual(
            CodexProviderService.displayedUsedPercentage(
                for: window,
                now: Date(timeIntervalSince1970: 1_699_999_999)
            ),
            100
        )
        XCTAssertEqual(
            CodexProviderService.displayedUsedPercentage(
                for: window,
                now: Date(timeIntervalSince1970: 1_700_000_001)
            ),
            0
        )
    }

    @MainActor
    func testOverlayShowsFiveHourAndSevenDayBucketsSeparately() {
        let data = ProviderUsageData(
            provider: .codex,
            isAvailable: true,
            usedPercentage: 5,
            remainingPercentage: 95,
            primaryWindowLabel: "5h",
            rateLimitBuckets: [
                RateBucket(label: "5h", utilization: 5),
                RateBucket(label: "1w", utilization: 86, isWarning: true),
                RateBucket(label: "Spark", utilization: 100, isWarning: true),
            ]
        )

        let buckets = PillView.overlayWindowBuckets(for: data)

        XCTAssertEqual(buckets.map(\.label), ["5H", "7D"])
        XCTAssertEqual(buckets.map(\.percentage), [95, 14])
        XCTAssertEqual(buckets.map(\.showWarning), [false, true])
    }

    func testRateWindowPaceFlagsFastBurnAgainstResetWindow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let pace = RateWindowPace.assess(
            label: "5h",
            utilization: 80,
            resetsAt: now.addingTimeInterval(2 * 60 * 60),
            now: now
        )

        XCTAssertEqual(pace.expectedUtilization, 60, accuracy: 0.001)
        XCTAssertEqual(pace.status, .burningFast)
    }

    func testRateWindowPaceRecognizesPlentyLeft() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let pace = RateWindowPace.assess(
            label: "1w",
            utilization: 20,
            resetsAt: now.addingTimeInterval(2 * AppConstants.secondsPerDay),
            now: now
        )

        XCTAssertEqual(pace.expectedUtilization, 71.428_571, accuracy: 0.001)
        XCTAssertEqual(pace.status, .plentyLeft)
    }

    func testRateWindowPaceIsUnavailableWithoutResetTime() {
        let pace = RateWindowPace.assess(
            label: "5h",
            utilization: 25,
            resetsAt: nil
        )

        XCTAssertEqual(pace.expectedUtilization, 0)
        XCTAssertEqual(pace.status, .unavailable)
    }

    @MainActor
    func testOverlayHidesProvidersWithoutUsageData() {
        let usageMap: [CLIProvider: ProviderUsageData] = [
            .claudeCode: .empty(for: .claudeCode),
            .codex: ProviderUsageData(
                provider: .codex,
                isAvailable: true,
                usedPercentage: 15,
                remainingPercentage: 85,
                primaryWindowLabel: "5h"
            ),
        ]

        let providers = PillView.visibleOverlayProviders(
            activeProviders: [.claudeCode, .codex],
            recentlyActiveProviders: [.claudeCode],
            usageData: { usageMap[$0] ?? .empty(for: $0) }
        )

        XCTAssertEqual(providers, [.codex])
    }

    @MainActor
    func testStaleThresholdMarksTwoMissedRefreshesAsStale() {
        let settings = AppSettings()
        let previousInterval = settings.refreshInterval
        settings.refreshInterval = 60
        defer {
            settings.refreshInterval = previousInterval
        }

        let service = MultiProviderUsageService()
        service.configure(settings: settings)

        XCTAssertFalse(service.isStale(lastRefresh: Date().addingTimeInterval(-90)))
        XCTAssertTrue(service.isStale(lastRefresh: Date().addingTimeInterval(-121)))
    }
}
