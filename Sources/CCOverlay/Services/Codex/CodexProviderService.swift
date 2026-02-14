import Foundation
import Observation

@Observable
@MainActor
final class CodexProviderService {
    let provider: CLIProvider = .codex

    private let apiKeyService = OpenAIAPIService()
    private var oauthService: CodexOAuthService?
    private var detection: CodexDetector.Detection?
    private var apiKeySnapshot: OpenAIAPIService.UsageSnapshot?
    private var oauthSnapshot: CodexOAuthService.UsageSnapshot?
    private var refreshTimer: Timer?

    private(set) var isDetected = false
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var lastRefresh: Date?

    /// Whether we're using OAuth (chatgpt) auth instead of API key
    private var isOAuthMode: Bool { detection?.chatgptAuth != nil }

    /// Detect Codex CLI binary and auth credentials.
    /// Supports both API key and ChatGPT OAuth modes.
    func detect(manualAPIKey: String? = nil) async -> Bool {
        detection = CodexDetector.detect(manualAPIKey: manualAPIKey)
        isDetected = detection?.binaryPath != nil

        switch detection?.authMode {
        case .apiKey(let key):
            isAuthenticated = true
            await apiKeyService.configure(apiKey: key)
            oauthService = nil
        case .chatgpt(let auth):
            isAuthenticated = true
            if let existing = oauthService {
                await existing.updateAuth(auth)
            } else {
                oauthService = CodexOAuthService(auth: auth)
            }
        case nil:
            isAuthenticated = false
            oauthService = nil
        }

        return isDetected && isAuthenticated
    }

    func startMonitoring(interval: TimeInterval = AppConstants.defaultRefreshInterval) {
        refresh()

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() {
        isLoading = true
        Task {
            await fetchUsage()
            isLoading = false
        }
    }

    private func fetchUsage() async {
        if isOAuthMode {
            await fetchOAuthUsage()
        } else {
            await fetchAPIKeyUsage()
        }
    }

    // MARK: - OAuth Usage

    private func fetchOAuthUsage() async {
        guard let oauthService else {
            self.error = "OAuth service not configured"
            return
        }

        do {
            let snap = try await oauthService.fetchUsage()
            self.oauthSnapshot = snap
            self.lastRefresh = Date()
            self.error = nil
        } catch {
            if let oauthError = error as? CodexOAuthService.OAuthError,
               case .tokenRevoked = oauthError {
                self.error = "Codex auth revoked — run 'codex --login' then restart app"
            } else if self.oauthSnapshot == nil {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - API Key Usage

    private func fetchAPIKeyUsage() async {
        do {
            let snap = try await apiKeyService.fetchUsage()
            self.apiKeySnapshot = snap
            self.lastRefresh = Date()
            self.error = nil
        } catch {
            if self.apiKeySnapshot == nil {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Unified ProviderUsageData

    var usageData: ProviderUsageData {
        if isOAuthMode {
            return oauthUsageData
        } else {
            return apiKeyUsageData
        }
    }

    // MARK: - OAuth -> ProviderUsageData

    private var oauthUsageData: ProviderUsageData {
        guard let snap = oauthSnapshot else {
            return .empty(
                for: .codex,
                error: error,
                lastRefresh: lastRefresh,
                isLoading: isLoading
            )
        }

        let primaryUsedPct = Double(snap.primaryWindow?.usedPercent ?? 0)
        let secondaryUsedPct = Double(snap.secondaryWindow?.usedPercent ?? 0)
        let remainPct = 100.0 - primaryUsedPct

        // Primary window label
        let primaryLabel: String
        if let pw = snap.primaryWindow, pw.limitWindowSeconds > 0 {
            let hours = pw.limitWindowSeconds / 3600
            primaryLabel = hours > 0 ? "\(hours)h" : "\(pw.limitWindowSeconds / 60)m"
        } else {
            primaryLabel = "5h"
        }

        // Reset time from primary window
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
                isWarning: primaryUsedPct >= 70
            ))
        }
        if let sw = snap.secondaryWindow {
            let secondaryLabel: String
            if sw.limitWindowSeconds > 0 {
                let days = sw.limitWindowSeconds / 86400
                secondaryLabel = days > 0 ? "\(days)d" : "\(sw.limitWindowSeconds / 3600)h"
            } else {
                secondaryLabel = "7d"
            }
            var secondaryResets: Date?
            if sw.resetAt > 0 {
                secondaryResets = Date(timeIntervalSince1970: TimeInterval(sw.resetAt))
            }
            buckets.append(RateBucket(
                label: secondaryLabel,
                utilization: secondaryUsedPct,
                resetsAt: secondaryResets,
                isWarning: secondaryUsedPct >= 70
            ))
        }

        // Include additional rate limit windows (e.g. per-model limits)
        for limit in snap.additionalLimits {
            if let pw = limit.primaryWindow {
                var limitResets: Date?
                if pw.resetAt > 0 {
                    limitResets = Date(timeIntervalSince1970: TimeInterval(pw.resetAt))
                }
                buckets.append(RateBucket(
                    label: limit.limitName,
                    utilization: Double(pw.usedPercent),
                    resetsAt: limitResets,
                    isWarning: pw.usedPercent >= 70
                ))
            }
        }

        // Build plan name with credits info
        var planName = snap.planType.capitalized
        if let credits = snap.credits {
            if credits.unlimited {
                planName += " (Unlimited)"
            } else if let balance = credits.balance, balance != "0" {
                planName += " (\(balance))"
            }
        }

        // Build CreditsDisplayInfo
        let creditsDisplay = CreditsDisplayInfo(
            planType: snap.planType.capitalized,
            hasCredits: snap.credits?.hasCredits ?? false,
            unlimited: snap.credits?.unlimited ?? false,
            balance: snap.credits?.balance,
            extraUsageEnabled: snap.extraUsageEnabled
        )

        // Build DetailedRateWindows
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
            let secLabel: String
            if sw.limitWindowSeconds > 0 {
                let days = sw.limitWindowSeconds / 86400
                secLabel = days > 0 ? "\(days)d" : "\(sw.limitWindowSeconds / 3600)h"
            } else {
                secLabel = "7d"
            }
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
                var limitResets: Date?
                if pw.resetAt > 0 {
                    limitResets = Date(timeIntervalSince1970: TimeInterval(pw.resetAt))
                }
                detailedWindows.append(DetailedRateWindow(
                    id: limit.limitName,
                    label: limit.limitName,
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
            usedPercentage: primaryUsedPct,
            remainingPercentage: remainPct,
            primaryWindowLabel: primaryLabel,
            resetsAt: resetsAt,
            rateLimitBuckets: buckets,
            planName: planName,
            estimatedCost: nil,
            tokenBreakdown: nil,
            enterpriseQuota: nil,
            creditsInfo: creditsDisplay,
            detailedRateWindows: detailedWindows,
            error: error,
            lastRefresh: lastRefresh,
            isLoading: isLoading
        )
    }

    // MARK: - API Key -> ProviderUsageData

    private var apiKeyUsageData: ProviderUsageData {
        guard let snap = apiKeySnapshot else {
            return .empty(
                for: .codex,
                error: error,
                lastRefresh: lastRefresh,
                isLoading: isLoading
            )
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
                isWarning: usedPct >= 70
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
            tokenBreakdown: nil,
            enterpriseQuota: nil,
            creditsInfo: nil,
            detailedRateWindows: nil,
            error: error,
            lastRefresh: lastRefresh,
            isLoading: isLoading
        )
    }
}
