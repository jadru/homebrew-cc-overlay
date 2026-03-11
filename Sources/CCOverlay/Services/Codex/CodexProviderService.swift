import Foundation
import Observation

@Observable
@MainActor
final class CodexProviderService: BaseProviderService {
    private let apiKeyService = OpenAIAPIService()
    private var oauthService: CodexOAuthService?
    private var detection: CodexDetector.Detection?
    private var apiKeySnapshot: OpenAIAPIService.UsageSnapshot?
    private var oauthSnapshot: CodexOAuthService.UsageSnapshot?

    /// Whether we're using OAuth (chatgpt) auth instead of API key
    private var isOAuthMode: Bool { detection?.chatgptAuth != nil }

    init() {
        super.init(provider: .codex)
    }

    // MARK: - Detection

    /// Detect Codex CLI binary and auth credentials.
    /// Supports both API key and ChatGPT OAuth modes.
    func detect(manualAPIKey: String? = nil) async -> Bool {
        detection = CodexDetector.detect(manualAPIKey: manualAPIKey)
        setDetected(detection?.binaryPath != nil)

        switch detection?.authMode {
        case .apiKey(let key):
            setAuthenticated(true)
            await apiKeyService.configure(apiKey: key)
            oauthService = nil
        case .chatgpt(let auth):
            setAuthenticated(true)
            if let existing = oauthService {
                await existing.updateAuth(auth)
            } else {
                oauthService = CodexOAuthService(auth: auth)
            }
        case nil:
            setAuthenticated(false)
            oauthService = nil
        }

        return isDetected && isAuthenticated
    }

    // MARK: - Fetch

    override func fetchUsage() async {
        if isOAuthMode {
            await fetchOAuthUsage()
        } else {
            await fetchAPIKeyUsage()
        }
    }

    private func fetchOAuthUsage() async {
        guard let oauthService else {
            setError("OAuth service not configured")
            return
        }

        do {
            let snap = try await oauthService.fetchUsage()
            trackActivity(newUsedPct: Double(snap.primaryWindow?.usedPercent ?? 0))
            self.oauthSnapshot = snap
            markRefreshed()
        } catch {
            if let oauthError = error as? CodexOAuthService.OAuthError,
               case .tokenRevoked = oauthError {
                setError("Codex auth revoked — run 'codex --login' then restart app")
            } else if self.oauthSnapshot == nil {
                setError(error.localizedDescription)
            }
        }
    }

    private func fetchAPIKeyUsage() async {
        do {
            let snap = try await apiKeyService.fetchUsage()
            trackActivity(newUsedPct: snap.budgetUtilization)
            self.apiKeySnapshot = snap
            markRefreshed()
        } catch {
            if self.apiKeySnapshot == nil {
                setError(error.localizedDescription)
            }
        }
    }

    // MARK: - Usage Data

    override var usageData: ProviderUsageData {
        if isOAuthMode {
            return oauthUsageData
        } else {
            return apiKeyUsageData
        }
    }

    // MARK: - OAuth -> ProviderUsageData

    private var oauthUsageData: ProviderUsageData {
        guard let snap = oauthSnapshot else {
            return .empty(for: .codex, error: error, lastRefresh: lastRefresh, isLoading: isLoading)
        }

        let primaryUsedPct = Double(snap.primaryWindow?.usedPercent ?? 0)
        let secondaryUsedPct = Double(snap.secondaryWindow?.usedPercent ?? 0)
        let effectiveUsedPct = Self.effectiveUsedPercentage(
            primaryUsedPct: primaryUsedPct,
            secondaryWindow: snap.secondaryWindow,
            additionalLimits: snap.additionalLimits
        )
        let remainPct = 100.0 - effectiveUsedPct

        let primaryLabel = Self.normalizedWindowLabel(
            windowSeconds: snap.primaryWindow?.limitWindowSeconds ?? 0,
            fallback: "5h"
        )

        var resetsAt: Date?
        if let pw = snap.primaryWindow, pw.resetAt > 0 {
            resetsAt = Date(timeIntervalSince1970: TimeInterval(pw.resetAt))
        }

        // Build rate limit buckets
        var buckets: [RateBucket] = []
        if snap.primaryWindow != nil {
            buckets.append(RateBucket(
                label: primaryLabel,
                utilization: primaryUsedPct,
                resetsAt: resetsAt,
                isWarning: primaryUsedPct >= AppConstants.warningThresholdPct
            ))
        }
        if let sw = snap.secondaryWindow {
            let secondaryLabel = Self.normalizedWindowLabel(
                windowSeconds: sw.limitWindowSeconds,
                fallback: "1w"
            )
            var secondaryResets: Date?
            if sw.resetAt > 0 {
                secondaryResets = Date(timeIntervalSince1970: TimeInterval(sw.resetAt))
            }
            buckets.append(RateBucket(
                label: secondaryLabel,
                utilization: secondaryUsedPct,
                resetsAt: secondaryResets,
                isWarning: secondaryUsedPct >= AppConstants.warningThresholdPct
            ))
        }
        for limit in snap.additionalLimits {
            if let pw = limit.primaryWindow {
                let limitLabel = Self.normalizedAdditionalLimitLabel(
                    limitName: limit.limitName,
                    meteredFeature: limit.meteredFeature
                )
                var limitResets: Date?
                if pw.resetAt > 0 {
                    limitResets = Date(timeIntervalSince1970: TimeInterval(pw.resetAt))
                }
                buckets.append(RateBucket(
                    label: limitLabel,
                    utilization: Double(pw.usedPercent),
                    resetsAt: limitResets,
                    isWarning: pw.usedPercent >= Int(AppConstants.warningThresholdPct)
                ))
            }
        }

        // Plan name with credits
        var planName = snap.planType.capitalized
        if let credits = snap.credits {
            if credits.unlimited {
                planName += " (Unlimited)"
            } else if let balance = credits.balance, balance != "0" {
                planName += " (\(balance))"
            }
        }

        let creditsDisplay = CreditsDisplayInfo(
            planType: snap.planType.capitalized,
            hasCredits: snap.credits?.hasCredits ?? false,
            unlimited: snap.credits?.unlimited ?? false,
            balance: snap.credits?.balance,
            extraUsageEnabled: snap.extraUsageEnabled
        )

        // Detailed rate windows
        var detailedWindows: [DetailedRateWindow] = []
        if let pw = snap.primaryWindow {
            detailedWindows.append(DetailedRateWindow(
                id: "primary",
                label: "Primary (\(primaryLabel))",
                usedPercent: Double(pw.usedPercent),
                remainingPercent: 100.0 - Double(pw.usedPercent),
                windowDuration: primaryLabel,
                resetsAt: resetsAt,
                resetAfterSeconds: pw.resetAfterSeconds > 0 ? pw.resetAfterSeconds : nil,
                isPrimary: true
            ))
        }
        if let sw = snap.secondaryWindow {
            let secLabel = Self.normalizedWindowLabel(
                windowSeconds: sw.limitWindowSeconds,
                fallback: "1w"
            )
            var secResets: Date?
            if sw.resetAt > 0 {
                secResets = Date(timeIntervalSince1970: TimeInterval(sw.resetAt))
            }
            detailedWindows.append(DetailedRateWindow(
                id: "secondary",
                label: "Weekly (\(secLabel))",
                usedPercent: Double(sw.usedPercent),
                remainingPercent: 100.0 - Double(sw.usedPercent),
                windowDuration: secLabel,
                resetsAt: secResets,
                resetAfterSeconds: sw.resetAfterSeconds > 0 ? sw.resetAfterSeconds : nil,
                isPrimary: false
            ))
        }
        for limit in snap.additionalLimits {
            if let pw = limit.primaryWindow {
                let limitLabel = Self.normalizedAdditionalLimitLabel(
                    limitName: limit.limitName,
                    meteredFeature: limit.meteredFeature
                )
                var limitResets: Date?
                if pw.resetAt > 0 {
                    limitResets = Date(timeIntervalSince1970: TimeInterval(pw.resetAt))
                }
                detailedWindows.append(DetailedRateWindow(
                    id: limitLabel,
                    label: limitLabel,
                    usedPercent: Double(pw.usedPercent),
                    remainingPercent: 100.0 - Double(pw.usedPercent),
                    windowDuration: "",
                    resetsAt: limitResets,
                    resetAfterSeconds: pw.resetAfterSeconds > 0 ? pw.resetAfterSeconds : nil,
                    isPrimary: false
                ))
            }
        }

        return ProviderUsageData(
            provider: .codex,
            isAvailable: true,
            usedPercentage: effectiveUsedPct,
            remainingPercentage: remainPct,
            primaryWindowLabel: primaryLabel,
            resetsAt: resetsAt,
            rateLimitBuckets: buckets,
            planName: planName,
            creditsInfo: creditsDisplay,
            detailedRateWindows: detailedWindows,
            lastActivityAt: lastActivityAt,
            error: error,
            lastRefresh: lastRefresh,
            isLoading: isLoading
        )
    }

    nonisolated static func normalizedWindowLabel(windowSeconds: Int, fallback: String) -> String {
        guard windowSeconds > 0 else { return fallback }

        if windowSeconds % Int(AppConstants.secondsPerDay) == 0 {
            let days = windowSeconds / Int(AppConstants.secondsPerDay)
            if days == 7 {
                return "1w"
            }
            return "\(days)d"
        }

        let hours = windowSeconds / 3600
        if hours > 0 {
            return "\(hours)h"
        }

        return "\(windowSeconds / 60)m"
    }

    nonisolated static func normalizedAdditionalLimitLabel(limitName: String, meteredFeature: String?) -> String {
        let candidates = [limitName, meteredFeature ?? ""].map { $0.lowercased() }

        if candidates.contains(where: { $0.contains("spark") }) {
            return "Spark"
        }
        if candidates.contains(where: { $0.contains("sonnet") }) {
            return "Sonnet"
        }

        let trimmed = limitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Session" }
        return trimmed
    }

    nonisolated static func effectiveUsedPercentage(
        primaryUsedPct: Double,
        secondaryWindow: CodexOAuthService.RateLimitWindow?,
        additionalLimits: [CodexOAuthService.AdditionalLimit]
    ) -> Double {
        var candidates = [primaryUsedPct]

        if let secondaryWindow {
            candidates.append(Double(secondaryWindow.usedPercent))
        }

        for limit in additionalLimits {
            if let primaryWindow = limit.primaryWindow {
                candidates.append(Double(primaryWindow.usedPercent))
            }
        }

        return min(candidates.max() ?? primaryUsedPct, 100)
    }

    // MARK: - API Key -> ProviderUsageData

    private var apiKeyUsageData: ProviderUsageData {
        guard let snap = apiKeySnapshot else {
            return .empty(for: .codex, error: error, lastRefresh: lastRefresh, isLoading: isLoading)
        }

        let primaryLabel: String
        let usedPct: Double
        let remainPct: Double

        if let credits = snap.credits, credits.totalGranted > 0 {
            primaryLabel = "Credits"
            usedPct = snap.budgetUtilization
            remainPct = 100.0 - usedPct
        } else {
            primaryLabel = "Monthly"
            usedPct = snap.budgetUtilization
            remainPct = 100.0 - usedPct
        }

        var buckets: [RateBucket] = []
        if snap.billing.hardLimitUSD > 0 || (snap.credits?.totalGranted ?? 0) > 0 {
            buckets.append(RateBucket(
                label: primaryLabel,
                utilization: usedPct,
                resetsAt: snap.periodEnd,
                isWarning: usedPct >= AppConstants.warningThresholdPct
            ))
        }

        let cost = CostSummary(
            windowCost: snap.dailyUsageUSD,
            windowLabel: "today",
            dailyCost: snap.monthlyUsageUSD,
            dailyLabel: "Monthly",
            breakdown: nil
        )

        return ProviderUsageData(
            provider: .codex,
            isAvailable: true,
            usedPercentage: usedPct,
            remainingPercentage: remainPct,
            primaryWindowLabel: primaryLabel,
            resetsAt: snap.periodEnd,
            rateLimitBuckets: buckets,
            planName: snap.billing.planName,
            estimatedCost: cost,
            lastActivityAt: lastActivityAt,
            error: error,
            lastRefresh: lastRefresh,
            isLoading: isLoading
        )
    }
}
