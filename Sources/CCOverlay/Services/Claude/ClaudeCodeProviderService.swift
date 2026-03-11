import Foundation
import Observation

@Observable
@MainActor
final class ClaudeCodeProviderService: BaseProviderService {
    private let apiService = AnthropicAPIService()
    private let claudeProjectsPath: String
    private let weightedCostLimitProvider: () -> Double
    private(set) var aggregatedUsage: AggregatedUsage = .empty
    private(set) var oauthUsage: OAuthUsageStatus = .empty
    private(set) var detectedPlanIdentifier: String?
    private var fileWatcher: FileWatcher?

    init(
        claudeProjectsPath: String = AppConstants.claudeProjectsPath,
        weightedCostLimitProvider: @escaping () -> Double = { PlanTier.pro.weightedCostLimit }
    ) {
        self.claudeProjectsPath = claudeProjectsPath
        self.weightedCostLimitProvider = weightedCostLimitProvider
        super.init(provider: .claudeCode)
    }

    /// Check if Claude Code CLI is installed and has valid credentials.
    func detect() -> Bool {
        let fm = FileManager.default
        let detected = fm.fileExists(atPath: claudeProjectsPath)
        setDetected(detected)

        // Check Keychain for OAuth credentials
        var hasToken = false
        var keychainNote: String?
        do {
            _ = try KeychainHelper.readClaudeOAuthToken()
            hasToken = true
        } catch let error as KeychainHelper.KeychainError where error.isAccessDenied {
            keychainNote = "access-denied"
            AppLogger.auth.error("Keychain access denied during detection — user must allow in Keychain Access")
        } catch {
            keychainNote = "not-found"
        }
        setAuthenticated(hasToken)

        DebugFlowLogger.shared.log(
            stage: .detection,
            provider: .claudeCode,
            message: detected && hasToken ? "detected" : "not-detected",
            details: [
                "projectsPath": claudeProjectsPath,
                "projectsPathExists": "\(detected)",
                "authenticated": "\(hasToken)",
                "keychainNote": keychainNote ?? "ok",
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
            detectedPlanIdentifier = await apiService.detectedPlanIdentifier()
        }
    }

    override func stopMonitoring() {
        fileWatcher?.stop()
        fileWatcher = nil
        super.stopMonitoring()
    }

    override func fetchUsage() async {
        do {
            let allEntries = try discoverAndParseAllSessions()
            aggregatedUsage = UsageCalculator.aggregate(entries: allEntries)
            setError(nil)
        } catch {
            AppLogger.data.error("JSONL refresh failed: \(error.localizedDescription)")
            setError(error.localizedDescription)
        }

        do {
            let usage = try await apiService.fetchUsage()
            detectedPlanIdentifier = await apiService.detectedPlanIdentifier()
            oauthUsage = usage
            setError(nil)
            AppLogger.network.debug(
                "OAuth OK: 5h=\(usage.fiveHour.utilization)% 7d=\(usage.sevenDay.utilization)% sonnet=\(usage.sevenDaySonnet?.utilization ?? -1)"
            )
            trackActivity(newUsedPct: usage.usedPercentage)
        } catch let keychainError as KeychainHelper.KeychainError {
            oauthUsage = .empty
            if keychainError.isAccessDenied {
                AppLogger.auth.error("Keychain access denied for Claude OAuth token")
                setError(keychainError.localizedDescription)
            } else {
                AppLogger.auth.debug("No OAuth credentials - JSONL-only fallback")
            }
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
