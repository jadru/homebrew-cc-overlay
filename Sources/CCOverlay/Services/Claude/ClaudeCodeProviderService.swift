import Foundation
import Observation

@Observable
@MainActor
final class ClaudeCodeProviderService: BaseProviderService {
    private let apiService = AnthropicAPIService()
    private let claudeProjectsPath: String
    private let weightedCostLimitProvider: () -> Double
    private let oauthAccessEnabled: () -> Bool
    private(set) var aggregatedUsage: AggregatedUsage = .empty
    private(set) var oauthUsage: OAuthUsageStatus = .empty
    private(set) var detectedPlanIdentifier: String?
    private var fileWatcher: FileWatcher?
    private var sessionFileStates: [String: ClaudeSessionScanner.FileState] = [:]

    init(
        claudeProjectsPath: String = AppConstants.claudeProjectsPath,
        weightedCostLimitProvider: @escaping () -> Double = { PlanTier.pro.weightedCostLimit },
        oauthAccessEnabled: @escaping () -> Bool = { false }
    ) {
        self.claudeProjectsPath = claudeProjectsPath
        self.weightedCostLimitProvider = weightedCostLimitProvider
        self.oauthAccessEnabled = oauthAccessEnabled
        super.init(provider: .claudeCode)
    }

    /// Check if Claude Code CLI is installed and has valid credentials.
    func detect() -> Bool {
        let hasRecentSession = ClaudeSessionScanner.hasRecentSession(projectsPath: claudeProjectsPath)

        // OAuth access is explicit because the Keychain item can require user authorization.
        var hasToken = false
        let shouldReadOAuth = oauthAccessEnabled()
        var keychainNote = shouldReadOAuth ? "not-found" : "not-requested"
        if shouldReadOAuth {
            do {
                _ = try KeychainHelper.readClaudeOAuthToken()
                hasToken = true
                keychainNote = "ok"
            } catch let error as KeychainHelper.KeychainError where error.isAccessDenied {
                keychainNote = "access-denied"
                AppLogger.auth.error("Keychain access denied during Claude OAuth detection")
            } catch {
                keychainNote = "not-found"
            }
        }
        setAuthenticated(hasToken)
        let detected = hasToken || hasRecentSession
        setDetected(detected)

        DebugFlowLogger.shared.log(
            stage: .detection,
            provider: .claudeCode,
            message: detected ? "detected" : "not-detected",
            details: [
                "projectsPath": claudeProjectsPath,
                "hasRecentSession": "\(hasRecentSession)",
                "oauthRequested": "\(shouldReadOAuth)",
                "authenticated": "\(hasToken)",
                "keychainNote": keychainNote,
            ]
        )

        return detected
    }

    override func revalidate(settings: AppSettings?) async -> Bool {
        detect()
    }

    override func startMonitoring(interval: TimeInterval = AppConstants.defaultRefreshInterval) {
        super.startMonitoring(interval: interval)
        installFileWatcher()

        Task {
            if self.isAuthenticated {
                self.detectedPlanIdentifier = await self.apiService.detectedPlanIdentifier()
            }
        }
    }

    override func stopMonitoring() {
        fileWatcher?.stop()
        fileWatcher = nil
        super.stopMonitoring()
    }

    private func installFileWatcher() {
        fileWatcher?.stop()
        fileWatcher = FileWatcher(directory: claudeProjectsPath) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.installFileWatcher()
                self.refresh()
            }
        }
    }

    override func fetchUsage() async {
        var localDataWasRead = false
        do {
            let projectsPath = claudeProjectsPath
            let previousStates = sessionFileStates
            let scan = try await Task.detached(priority: .utility) {
                try ClaudeSessionScanner.scan(
                    projectsPath: projectsPath,
                    previousStates: previousStates
                )
            }.value
            sessionFileStates = scan.fileStates
            aggregatedUsage = UsageCalculator.aggregate(entries: scan.entries)
            localDataWasRead = true
        } catch {
            AppLogger.data.error("JSONL refresh failed: \(error.localizedDescription)")
            setError(error.localizedDescription)
        }

        guard isAuthenticated else {
            if localDataWasRead {
                markLocalRefreshed(clearingError: true)
            }
            return
        }

        guard canAttemptNetworkRefresh() else { return }

        do {
            let usage = try await apiService.fetchUsage()
            detectedPlanIdentifier = await apiService.detectedPlanIdentifier()
            oauthUsage = usage
            setError(nil)
            AppLogger.network.debug(
                "OAuth OK: 5h=\(usage.fiveHour.utilization)% 7d=\(usage.sevenDay.utilization)% sonnet=\(usage.sevenDaySonnet?.utilization ?? -1)"
            )
            trackActivity(newUsedPct: usage.usedPercentage)
            markRefreshed()
        } catch let keychainError as KeychainHelper.KeychainError {
            oauthUsage = .empty
            if keychainError.isAccessDenied {
                AppLogger.auth.error("Keychain access denied for Claude OAuth token")
                setError(keychainError.localizedDescription)
                recordNetworkFailure()
            } else {
                AppLogger.auth.debug("No OAuth credentials - JSONL-only fallback")
                setAuthenticated(false)
                if localDataWasRead {
                    markLocalRefreshed(clearingError: true)
                }
            }
        } catch {
            AppLogger.network.error("Rate limit fetch failed: \(error.localizedDescription)")
            recordNetworkFailure()
            setError(error.localizedDescription)
        }
    }

    override var usageData: ProviderUsageData {
        let oauth = oauthUsage
        let agg = aggregatedUsage
        let estimatedLimit = Self.resolvedWeightedCostLimit(
            planIdentifier: detectedPlanIdentifier,
            fallbackLimit: weightedCostLimitProvider()
        )
        let estimatedUsedPct = agg.usagePercentage(limit: estimatedLimit)
        let effectiveUsedPct = hasAPIData ? oauth.usedPercentage : estimatedUsedPct
        let effectiveRemainingPct = hasAPIData ? oauth.remainingPercentage : max(0, 100.0 - estimatedUsedPct)
        let effectivePlanName = Self.resolvedPlanName(
            planIdentifier: detectedPlanIdentifier,
            hasAPIData: hasAPIData
        )
        let exhaustionPrediction = Self.predictedSessionExhaustion(
            aggregatedUsage: agg,
            limit: estimatedLimit
        )

        let buckets: [RateBucket] = {
            if hasAPIData {
                var result: [RateBucket] = [
                    RateBucket(
                        label: "5h",
                        utilization: min(oauth.fiveHour.utilization, 100),
                        resetsAt: oauth.fiveHour.resetsAt
                    ),
                    RateBucket(
                        label: "1w",
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
            }

            guard agg.fiveHourWindow.totalTokens > 0 else { return [] }

            let result: [RateBucket] = [
                RateBucket(
                    label: "5h",
                    utilization: estimatedUsedPct,
                    resetsAt: nil,
                    isWarning: estimatedUsedPct >= AppConstants.warningThresholdPct
                ),
            ]
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
            isAvailable: hasAPIData || agg.fiveHourWindow.totalTokens > 0,
            isEstimated: !hasAPIData,
            usedPercentage: effectiveUsedPct,
            remainingPercentage: effectiveRemainingPct,
            primaryWindowLabel: "5h",
            resetsAt: hasAPIData ? oauth.primaryResetsAt : nil,
            rateLimitBuckets: buckets,
            planName: effectivePlanName,
            estimatedCost: cost,
            tokenBreakdown: tokenData,
            enterpriseQuota: oauth.enterpriseQuota,
            exhaustionPrediction: exhaustionPrediction,
            lastActivityAt: agg.currentSession?.lastTimestamp,
            error: error,
            lastRefresh: lastRefresh,
            isLoading: isLoading
        )
    }

    /// Whether we're using API-backed usage data.
    var hasAPIData: Bool {
        oauthUsage.isAvailable
    }

    nonisolated static func resolvedWeightedCostLimit(planIdentifier: String?, fallbackLimit: Double) -> Double {
        PlanTier.fromUsageIdentifier(planIdentifier)?.weightedCostLimit ?? fallbackLimit
    }

    nonisolated static func resolvedPlanName(planIdentifier: String?, hasAPIData: Bool) -> String? {
        guard let planIdentifier else { return nil }
        let displayName = PlanTier.displayName(for: planIdentifier)
        return hasAPIData ? displayName : "\(displayName) (est.)"
    }

    nonisolated static func predictedSessionExhaustion(
        aggregatedUsage: AggregatedUsage,
        limit: Double,
        now: Date = Date()
    ) -> RateLimitPrediction? {
        guard limit > 0,
              let session = aggregatedUsage.currentSession,
              session.messageCount >= 2
        else {
            return nil
        }

        guard now.timeIntervalSince(session.lastTimestamp) <= AppConstants.activityWindowSeconds * 2 else {
            return nil
        }

        let elapsed = max(session.lastTimestamp.timeIntervalSince(session.firstTimestamp), 60)
        let consumed = session.tokenUsage.weightedCost
        let remaining = aggregatedUsage.remainingCost(limit: limit)

        guard consumed > 0, remaining > 0 else { return nil }

        let hoursElapsed = elapsed / 3600
        let ratePerHour = consumed / hoursElapsed
        guard ratePerHour > 0 else { return nil }

        let hoursToLimit = remaining / ratePerHour
        let totalMinutes = max(Int(hoursToLimit * 60), 0)

        let formatted: String = {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if hours > 0 {
                return "~\(hours)h \(minutes)m left"
            }
            if minutes > 0 {
                return "~\(minutes)m left"
            }
            return "At limit"
        }()

        return RateLimitPrediction(
            estimatedExhaustionDate: now.addingTimeInterval(hoursToLimit * 3600),
            formattedTimeRemaining: formatted,
            consumptionRatePerHour: ratePerHour
        )
    }

    override var lastActivityAt: Date? {
        aggregatedUsage.currentSession?.lastTimestamp
    }

}
