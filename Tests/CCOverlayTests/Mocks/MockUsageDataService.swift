import Foundation
@testable import CCOverlay

/// A mock implementation of UsageDataServiceProtocol for testing.
@MainActor
final class MockUsageDataService: UsageDataServiceProtocol {
    var aggregatedUsage: AggregatedUsage
    var oauthUsage: OAuthUsageStatus
    var detectedPlan: String?
    var isLoading: Bool = false
    var lastRefresh: Date?
    var error: String?

    var usedPercentage: Double {
        if oauthUsage.isAvailable {
            return oauthUsage.usedPercentage
        }
        return 0
    }

    var remainingPercentage: Double {
        100.0 - usedPercentage
    }

    var hasAPIData: Bool {
        oauthUsage.isAvailable
    }

    // Tracking for verification in tests
    var startMonitoringCallCount = 0
    var stopMonitoringCallCount = 0
    var refreshCallCount = 0
    var lastInterval: TimeInterval?

    init(
        remainingPercentage: Double = 50.0,
        fiveHourUtilization: Double = 50.0,
        sevenDayUtilization: Double = 30.0,
        sonnetUtilization: Double? = nil,
        resetsAt: Date? = nil,
        detectedPlan: String? = nil,
        hasAPIData: Bool = true,
        fiveHourCost: CostBreakdown = .zero,
        dailyCost: CostBreakdown = .zero,
        error: String? = nil
    ) {
        self.detectedPlan = detectedPlan
        self.error = error
        self.lastRefresh = Date()

        // Create OAuthUsageStatus based on parameters
        if hasAPIData {
            let usedPct = 100.0 - remainingPercentage
            self.oauthUsage = OAuthUsageStatus(
                fiveHour: UsageBucket(utilization: fiveHourUtilization, resetsAt: resetsAt),
                sevenDay: UsageBucket(utilization: sevenDayUtilization, resetsAt: nil),
                sevenDaySonnet: sonnetUtilization.map { UsageBucket(utilization: $0, resetsAt: nil) },
                extraUsageEnabled: false,
                fetchedAt: Date()
            )
        } else {
            self.oauthUsage = .empty
        }

        // Create AggregatedUsage
        self.aggregatedUsage = AggregatedUsage(
            currentSession: nil,
            fiveHourWindow: .zero,
            dailyTotal: .zero,
            allSessions: [],
            fiveHourCost: fiveHourCost,
            dailyCost: dailyCost
        )
    }

    func startMonitoring(interval: TimeInterval) {
        startMonitoringCallCount += 1
        lastInterval = interval
    }

    func stopMonitoring() {
        stopMonitoringCallCount += 1
    }

    func updateRefreshInterval(_ interval: TimeInterval) {
        lastInterval = interval
    }

    func refresh() {
        refreshCallCount += 1
    }

    // MARK: - Test Helpers

    /// Simulates a loading state
    func simulateLoading() {
        isLoading = true
    }

    /// Simulates completion of loading
    func simulateLoadingComplete() {
        isLoading = false
        lastRefresh = Date()
    }

    /// Simulates an error state
    func simulateError(_ errorMessage: String) {
        error = errorMessage
        isLoading = false
    }

    /// Updates the remaining percentage for testing state changes
    func setRemainingPercentage(_ percentage: Double) {
        let usedPct = 100.0 - percentage
        self.oauthUsage = OAuthUsageStatus(
            fiveHour: UsageBucket(utilization: usedPct, resetsAt: oauthUsage.fiveHour.resetsAt),
            sevenDay: oauthUsage.sevenDay,
            sevenDaySonnet: oauthUsage.sevenDaySonnet,
            extraUsageEnabled: oauthUsage.extraUsageEnabled,
            fetchedAt: Date()
        )
    }
}
