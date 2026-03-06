import Foundation
import Observation

@Observable
@MainActor
final class ClaudeCodeProviderService: BaseProviderService {
    private let apiService = AnthropicAPIService()
    private let claudeProjectsPath: String
    private(set) var aggregatedUsage: AggregatedUsage = .empty
    private(set) var projectCostSummaries: [ProjectCostSummary] = []
    private(set) var modelCostSummaries: [ModelUsageSummary] = []
    private(set) var oauthUsage: OAuthUsageStatus = .empty
    private(set) var detectedPlan: String?
    private var fileWatcher: FileWatcher?
    private let usageHistoryService: UsageHistoryService?

    init(
        claudeProjectsPath: String = AppConstants.claudeProjectsPath,
        usageHistoryService: UsageHistoryService? = nil
    ) {
        self.claudeProjectsPath = claudeProjectsPath
        self.usageHistoryService = usageHistoryService
        super.init(provider: .claudeCode)
    }

    /// Check if Claude Code CLI is installed and has valid credentials.
    func detect() -> Bool {
        let fm = FileManager.default
        let detected = fm.fileExists(atPath: claudeProjectsPath)
        setDetected(detected)

        // Check Keychain for OAuth credentials
        let hasToken = (try? KeychainHelper.readClaudeOAuthToken()) != nil
        setAuthenticated(hasToken)

        DebugFlowLogger.shared.log(
            stage: .detection,
            provider: .claudeCode,
            message: detected && hasToken ? "detected" : "not-detected",
            details: [
                "projectsPath": claudeProjectsPath,
                "projectsPathExists": "\(detected)",
                "authenticated": "\(hasToken)",
            ]
        )

        return detected
    }

    override func startMonitoring(interval: TimeInterval = AppConstants.defaultRefreshInterval) {
        super.startMonitoring(interval: interval)

        fileWatcher?.stop()
        fileWatcher = FileWatcher(directory: claudeProjectsPath) { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }

        Task {
            detectedPlan = await apiService.detectedSubscriptionType()
        }
    }

    override func stopMonitoring() {
        fileWatcher?.stop()
        fileWatcher = nil
        super.stopMonitoring()
    }

    override func fetchUsage() async {
        let usageForSnapshot: AggregatedUsage

        do {
            let allEntries = try discoverAndParseAllSessions()
            usageForSnapshot = UsageCalculator.aggregate(entries: allEntries)
            aggregatedUsage = usageForSnapshot
            projectCostSummaries = UsageCalculator.aggregateByProject(entries: allEntries)
            modelCostSummaries = UsageCalculator.aggregateByModel(entries: allEntries)
            setError(nil)
        } catch {
            AppLogger.data.error("JSONL refresh failed: \(error.localizedDescription)")
            setError(error.localizedDescription)
            usageForSnapshot = aggregatedUsage
            projectCostSummaries = []
            modelCostSummaries = []
        }

        if let usageHistoryService {
            usageHistoryService.recordSnapshot(
                usage: usageForSnapshot.fiveHourWindow,
                cost: usageForSnapshot.fiveHourCost,
                provider: .claudeCode
            )
        }

        do {
            let usage = try await apiService.fetchUsage()
            oauthUsage = usage
            setError(nil)
            trackActivity(newUsedPct: usage.usedPercentage)
        } catch is KeychainHelper.KeychainError {
            // No credentials — silently fall back to JSONL-only mode
        } catch {
            AppLogger.network.error("Rate limit fetch failed: \(error.localizedDescription)")
            if !oauthUsage.isAvailable {
                setError(error.localizedDescription)
            }
        }

        markRefreshed()
    }

    override var usageData: ProviderUsageData {
        let oauth = oauthUsage
        let agg = aggregatedUsage

        let buckets: [RateBucket] = {
            guard hasAPIData else { return [] }
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

        let sparklineData = usageHistoryService?.dailySnapshots(for: .claudeCode, days: 7).map { $0.totalCost } ?? []

        let exhaustionPrediction = hasAPIData ? RateLimitPredictor.predict(
            currentUtilization: oauth.usedPercentage,
            recentSnapshots: usageHistoryService?.dailySnapshots(for: .claudeCode, days: 7) ?? [],
            resetsAt: oauth.primaryResetsAt
        ) : nil

        return ProviderUsageData(
            provider: .claudeCode,
            isAvailable: hasAPIData || agg.fiveHourWindow.totalTokens > 0,
            usedPercentage: hasAPIData ? oauth.usedPercentage : 0,
            remainingPercentage: hasAPIData ? oauth.remainingPercentage : 100,
            primaryWindowLabel: "5h",
            resetsAt: oauth.primaryResetsAt,
            rateLimitBuckets: buckets,
            planName: detectedPlan.map { PlanTier.displayName(for: $0) },
            estimatedCost: cost,
            tokenBreakdown: tokenData,
            sparklineData: sparklineData,
            projectCosts: projectCostSummaries,
            modelBreakdowns: modelCostSummaries,
            enterpriseQuota: oauth.enterpriseQuota,
            exhaustionPrediction: exhaustionPrediction,
            isDetected: isDetected,
            isAuthenticated: isAuthenticated,
            lastActivityAt: agg.currentSession?.lastTimestamp,
            lastSuccessfulRefresh: lastSuccessfulRefresh,
            lastResponseDuration: lastResponseDuration,
            error: error,
            lastRefresh: lastRefresh,
            isLoading: isLoading
        )
    }

    /// Whether we're using API-backed usage data.
    var hasAPIData: Bool {
        oauthUsage.isAvailable
    }

    override var lastActivityAt: Date? {
        aggregatedUsage.currentSession?.lastTimestamp
    }

    /// Parse all sessions from Claude JSONL logs modified in the last 24h.
    private func discoverAndParseAllSessions() throws -> [ParsedUsageEntry] {
        let fm = FileManager.default
        let projectsURL = URL(fileURLWithPath: claudeProjectsPath)

        guard fm.fileExists(atPath: projectsURL.path) else { return [] }

        var allEntries: [ParsedUsageEntry] = []

        let projectDirs = try fm.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDir),
                  isDir.boolValue
            else { continue }

            let projectName = projectDir.lastPathComponent

            let files: [URL]
            do {
                files = try fm.contentsOfDirectory(
                    at: projectDir,
                    includingPropertiesForKeys: [.contentModificationDateKey]
                ).filter { $0.pathExtension == "jsonl" }
            } catch {
                continue
            }

            let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
            for file in files {
                if let attrs = try? fm.attributesOfItem(atPath: file.path),
                   let modDate = attrs[.modificationDate] as? Date,
                   modDate < oneDayAgo
                {
                    continue
                }

                if let entries = try? JSONLParser.parseSessionFile(at: file, projectName: projectName) {
                    allEntries.append(contentsOf: entries)
                }
            }
        }

        return allEntries
    }
}
