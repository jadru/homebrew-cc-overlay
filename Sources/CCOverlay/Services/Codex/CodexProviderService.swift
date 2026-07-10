import Foundation
import Observation

@Observable
@MainActor
final class CodexProviderService: BaseProviderService {
    private var oauthService: CodexOAuthService?
    private var oauthSnapshot: CodexOAuthService.UsageSnapshot?

    init() {
        super.init(provider: .codex)
    }

    // MARK: - Detection

    /// Codex rate limits are available only through the Codex CLI's ChatGPT login.
    func detect() async -> Bool {
        let detection = CodexDetector.detect()
        setDetected(detection.binaryPath != nil)

        guard let auth = detection.chatgptAuth else {
            setAuthenticated(false)
            oauthService = nil
            oauthSnapshot = nil
            return false
        }

        setAuthenticated(true)
        if let oauthService {
            await oauthService.updateAuth(auth)
        } else {
            oauthService = CodexOAuthService(auth: auth)
        }
        return isDetected
    }

    override func revalidate(settings: AppSettings?) async -> Bool {
        await detect()
    }

    // MARK: - Fetch

    override func fetchUsage() async {
        // Codex owns token refresh. This process only re-reads and uses its current auth file.
        guard await detect(), let oauthService else {
            setError("Codex CLI authentication is unavailable. Run 'codex --login'.")
            return
        }

        guard canAttemptNetworkRefresh() else { return }

        do {
            let snapshot = try await oauthService.fetchUsage()
            trackActivity(newUsedPct: Double(snapshot.primaryWindow?.usedPercent ?? 0))
            oauthSnapshot = snapshot
            markRefreshed()
        } catch {
            let retryAfter: TimeInterval?
            if case let CodexOAuthService.OAuthError.rateLimited(value) = error {
                retryAfter = value
            } else {
                retryAfter = nil
            }
            recordNetworkFailure(retryAfter: retryAfter)
            setError(error.localizedDescription)
        }
    }

    // MARK: - Usage Data

    override var usageData: ProviderUsageData {
        guard isAuthenticated, let snapshot = oauthSnapshot, snapshot.primaryWindow != nil else {
            return .empty(for: .codex, error: error, lastRefresh: lastRefresh, isLoading: isLoading)
        }

        let now = Date()
        let primaryUsedPct = Self.displayedUsedPercentage(for: snapshot.primaryWindow, now: now)
        let secondaryUsedPct = Self.displayedUsedPercentage(for: snapshot.secondaryWindow, now: now)
        let remainingPct = 100.0 - primaryUsedPct
        let primaryLabel = Self.normalizedWindowLabel(
            windowSeconds: snapshot.primaryWindow?.limitWindowSeconds ?? 0,
            fallback: "5h"
        )

        let resetsAt = Self.resetDate(for: snapshot.primaryWindow)
        var buckets = [
            RateBucket(
                label: primaryLabel,
                utilization: primaryUsedPct,
                resetsAt: resetsAt,
                isWarning: primaryUsedPct >= AppConstants.warningThresholdPct
            ),
        ]

        if let secondaryWindow = snapshot.secondaryWindow {
            let secondaryLabel = Self.normalizedWindowLabel(
                windowSeconds: secondaryWindow.limitWindowSeconds,
                fallback: "1w"
            )
            buckets.append(RateBucket(
                label: secondaryLabel,
                utilization: secondaryUsedPct,
                resetsAt: Self.resetDate(for: secondaryWindow),
                isWarning: secondaryUsedPct >= AppConstants.warningThresholdPct
            ))
        }

        for limit in snapshot.additionalLimits where limit.primaryWindow != nil {
            guard let window = limit.primaryWindow else { continue }
            let usedPct = Self.displayedUsedPercentage(for: window, now: now)
            buckets.append(RateBucket(
                label: Self.normalizedAdditionalLimitLabel(
                    limitName: limit.limitName,
                    meteredFeature: limit.meteredFeature
                ),
                utilization: usedPct,
                resetsAt: Self.resetDate(for: window),
                isWarning: usedPct >= AppConstants.warningThresholdPct
            ))
        }

        var planName = snapshot.planType.capitalized
        if let credits = snapshot.credits {
            if credits.unlimited {
                planName += " (Unlimited)"
            } else if let balance = credits.balance, balance != "0" {
                planName += " (\(balance))"
            }
        }

        let creditsDisplay = CreditsDisplayInfo(
            planType: snapshot.planType.capitalized,
            hasCredits: snapshot.credits?.hasCredits ?? false,
            unlimited: snapshot.credits?.unlimited ?? false,
            balance: snapshot.credits?.balance,
            extraUsageEnabled: snapshot.extraUsageEnabled
        )

        var detailedWindows = [DetailedRateWindow]()
        if let primaryWindow = snapshot.primaryWindow {
            detailedWindows.append(DetailedRateWindow(
                id: "primary",
                label: "Primary (\(primaryLabel))",
                usedPercent: primaryUsedPct,
                remainingPercent: remainingPct,
                windowDuration: primaryLabel,
                resetsAt: resetsAt,
                resetAfterSeconds: primaryWindow.resetAfterSeconds > 0 ? primaryWindow.resetAfterSeconds : nil,
                isPrimary: true
            ))
        }

        if let secondaryWindow = snapshot.secondaryWindow {
            let secondaryLabel = Self.normalizedWindowLabel(
                windowSeconds: secondaryWindow.limitWindowSeconds,
                fallback: "1w"
            )
            detailedWindows.append(DetailedRateWindow(
                id: "secondary",
                label: "Weekly (\(secondaryLabel))",
                usedPercent: secondaryUsedPct,
                remainingPercent: 100.0 - secondaryUsedPct,
                windowDuration: secondaryLabel,
                resetsAt: Self.resetDate(for: secondaryWindow),
                resetAfterSeconds: secondaryWindow.resetAfterSeconds > 0 ? secondaryWindow.resetAfterSeconds : nil,
                isPrimary: false
            ))
        }

        for limit in snapshot.additionalLimits where limit.primaryWindow != nil {
            guard let window = limit.primaryWindow else { continue }
            let label = Self.normalizedAdditionalLimitLabel(
                limitName: limit.limitName,
                meteredFeature: limit.meteredFeature
            )
            let usedPct = Self.displayedUsedPercentage(for: window, now: now)
            detailedWindows.append(DetailedRateWindow(
                id: label,
                label: label,
                usedPercent: usedPct,
                remainingPercent: 100.0 - usedPct,
                windowDuration: "",
                resetsAt: Self.resetDate(for: window),
                resetAfterSeconds: window.resetAfterSeconds > 0 ? window.resetAfterSeconds : nil,
                isPrimary: false
            ))
        }

        return ProviderUsageData(
            provider: .codex,
            isAvailable: true,
            usedPercentage: primaryUsedPct,
            remainingPercentage: remainingPct,
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
            return days == 7 ? "1w" : "\(days)d"
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
        return trimmed.isEmpty ? "Session" : trimmed
    }

    nonisolated static func displayedUsedPercentage(
        for window: CodexOAuthService.RateLimitWindow?,
        now: Date = Date()
    ) -> Double {
        guard let window else { return 0 }
        if window.resetAt > 0 && TimeInterval(window.resetAt) <= now.timeIntervalSince1970 {
            return 0
        }
        return min(max(Double(window.usedPercent), 0), 100)
    }

    private static func resetDate(for window: CodexOAuthService.RateLimitWindow?) -> Date? {
        guard let window, window.resetAt > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(window.resetAt))
    }
}
