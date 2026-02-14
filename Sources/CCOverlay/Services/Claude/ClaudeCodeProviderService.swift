import Foundation
import Observation

@Observable
@MainActor
final class ClaudeCodeProviderService {
    let provider: CLIProvider = .claudeCode

    private let inner: UsageDataService
    private(set) var isDetected = false
    private(set) var isAuthenticated = false

    init(claudeProjectsPath: String = AppConstants.claudeProjectsPath) {
        self.inner = UsageDataService(claudeProjectsPath: claudeProjectsPath)
    }

    /// Check if Claude Code CLI is installed and has valid credentials.
    func detect() -> Bool {
        let fm = FileManager.default
        isDetected = fm.fileExists(atPath: AppConstants.claudeProjectsPath)

        // Check Keychain for OAuth credentials
        isAuthenticated = (try? KeychainHelper.readClaudeOAuthToken()) != nil

        return isDetected
    }

    func startMonitoring(interval: TimeInterval = AppConstants.defaultRefreshInterval) {
        inner.startMonitoring(interval: interval)
    }

    func stopMonitoring() {
        inner.stopMonitoring()
    }

    func refresh() {
        inner.refresh()
    }

    var usageData: ProviderUsageData {
        let oauth = inner.oauthUsage
        let agg = inner.aggregatedUsage

        let buckets: [RateBucket] = {
            guard inner.hasAPIData else { return [] }
            var result: [RateBucket] = [
                RateBucket(
                    label: "5h",
                    utilization: min(oauth.fiveHour.utilization, 100),
                    resetsAt: oauth.fiveHour.resetsAt
                ),
                RateBucket(
                    label: "7d",
                    utilization: min(oauth.sevenDay.utilization, 100),
                    resetsAt: oauth.sevenDay.resetsAt,
                    isWarning: oauth.isWeeklyNearLimit
                ),
            ]
            if let sonnet = oauth.sevenDaySonnet {
                result.append(RateBucket(
                    label: "Sonnet",
                    utilization: min(sonnet.utilization, 100),
                    resetsAt: sonnet.resetsAt,
                    isWarning: sonnet.utilization >= OAuthUsageStatus.weeklyWarningThreshold
                ))
            }
            return result
        }()

        let cost = CostSummary(
            windowCost: agg.fiveHourCost.totalCost,
            windowLabel: "5h window",
            dailyCost: agg.dailyCost.totalCost,
            dailyLabel: "Today",
            breakdown: agg.fiveHourCost
        )

        let tokenData = TokenBreakdownData(
            title: "5-Hour Tokens",
            usage: agg.fiveHourWindow
        )

        return ProviderUsageData(
            provider: .claudeCode,
            isAvailable: inner.hasAPIData || agg.fiveHourWindow.totalTokens > 0,
            usedPercentage: inner.usedPercentage,
            remainingPercentage: inner.remainingPercentage,
            primaryWindowLabel: "5h",
            resetsAt: oauth.primaryResetsAt,
            rateLimitBuckets: buckets,
            planName: inner.detectedPlan.map { PlanTier.displayName(for: $0) },
            estimatedCost: cost,
            tokenBreakdown: tokenData,
            enterpriseQuota: inner.enterpriseQuota,
            creditsInfo: nil,
            detailedRateWindows: nil,
            error: inner.error,
            lastRefresh: inner.lastRefresh,
            isLoading: inner.isLoading
        )
    }

    // MARK: - Pass-through for backward compat during migration

    var innerService: UsageDataService { inner }
}
