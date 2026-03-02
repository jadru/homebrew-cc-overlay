import Foundation
@testable import CCOverlay

@MainActor
final class MockProviderService: ProviderServiceProtocol {
    let provider: CLIProvider
    let isDetected: Bool
    let isAuthenticated: Bool

    var isLoading: Bool = false
    var error: String?
    var lastRefresh: Date?
    var lastActivityAt: Date?

    var usedPercentage: Double
    var remainingPercentage: Double
    var isAvailable: Bool
    var usageData: ProviderUsageData

    // Tracking for verification in tests
    var startMonitoringCallCount = 0
    var stopMonitoringCallCount = 0
    var refreshCallCount = 0
    var lastInterval: TimeInterval?

    init(
        provider: CLIProvider = .claudeCode,
        remainingPercentage: Double = 50.0,
        resetsAt: Date? = nil,
        isDetected: Bool = true,
        isAuthenticated: Bool = true,
        error: String? = nil
    ) {
        self.provider = provider
        self.isDetected = isDetected
        self.isAuthenticated = isAuthenticated
        self.usedPercentage = max(0, min(100, 100 - remainingPercentage))
        self.remainingPercentage = max(0, min(100, remainingPercentage))
        self.isAvailable = isDetected && isAuthenticated
        self.lastRefresh = Date()
        self.error = error

        self.usageData = ProviderUsageData(
            provider: provider,
            isAvailable: isDetected && isAuthenticated,
            usedPercentage: self.usedPercentage,
            remainingPercentage: self.remainingPercentage,
            primaryWindowLabel: "5h",
            resetsAt: resetsAt,
            rateLimitBuckets: [
                RateBucket(label: "5h", utilization: self.usedPercentage, resetsAt: resetsAt)
            ]
        )
    }

    func fetchUsage() async {
        refreshCallCount += 1
    }

    func startMonitoring(interval: TimeInterval) {
        startMonitoringCallCount += 1
        lastInterval = interval
    }

    func stopMonitoring() {
        stopMonitoringCallCount += 1
    }

    func refresh() {
        refreshCallCount += 1
        lastRefresh = Date()
    }

    // MARK: - Test Helpers

    func simulateLoading() {
        isLoading = true
    }

    func simulateLoadingComplete() {
        isLoading = false
        lastRefresh = Date()
    }

    func simulateError(_ errorMessage: String) {
        error = errorMessage
        isLoading = false
        isAvailable = false
    }

    func setRemainingPercentage(_ percentage: Double) {
        remainingPercentage = max(0, min(100, percentage))
        usedPercentage = 100.0 - remainingPercentage
        isAvailable = true
        usageData = ProviderUsageData(
            provider: provider,
            isAvailable: isAvailable,
            usedPercentage: usedPercentage,
            remainingPercentage: remainingPercentage,
            primaryWindowLabel: "5h",
            resetsAt: usageData.resetsAt,
            rateLimitBuckets: [
                RateBucket(label: "5h", utilization: usedPercentage, resetsAt: usageData.resetsAt)
            ]
        )
    }
}
