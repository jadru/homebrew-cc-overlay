import Foundation
import Observation

@Observable
@MainActor
final class GeminiProviderService {
    let provider: CLIProvider = .gemini

    private let apiKeyService = GeminiAPIService()
    private var oauthService: GeminiOAuthService?
    private var detection: GeminiDetector.Detection?
    private var apiKeySnapshot: GeminiAPIService.UsageSnapshot?
    private var oauthSnapshot: GeminiOAuthService.UsageSnapshot?
    private var refreshTimer: Timer?
    private var refreshTask: Task<Void, Never>?

    private(set) var isDetected = false
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var lastRefresh: Date?

    /// Whether we're using Google OAuth instead of API key
    private var isOAuthMode: Bool { detection?.googleAuth != nil }

    /// Detect Gemini CLI binary and auth credentials.
    /// Supports both Google OAuth and API key modes.
    func detect(manualAPIKey: String? = nil) async -> Bool {
        detection = GeminiDetector.detect(manualAPIKey: manualAPIKey)
        isDetected = detection?.binaryPath != nil

        switch detection?.authMode {
        case .apiKey(let key):
            isAuthenticated = true
            await apiKeyService.configure(apiKey: key)
            oauthService = nil
        case .googleOAuth(let auth):
            isAuthenticated = true
            if let existing = oauthService {
                await existing.updateAuth(auth)
            } else {
                oauthService = GeminiOAuthService(auth: auth)
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
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() {
        isLoading = true
        refreshTask?.cancel()
        refreshTask = Task {
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
            if self.oauthSnapshot == nil {
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
                for: .gemini,
                error: error,
                lastRefresh: lastRefresh,
                isLoading: isLoading
            )
        }

        return buildUsageData(
            rpdUtilization: snap.rpdUtilization,
            rpmUtilization: snap.rpmUtilization,
            tier: snap.tier,
            inputTokens: snap.estimatedInputTokens,
            outputTokens: snap.estimatedOutputTokens,
            costToday: snap.estimatedCostToday,
            model: snap.model,
            planSuffix: snap.accountEmail.map { " (\($0))" }
        )
    }

    // MARK: - API Key -> ProviderUsageData

    private var apiKeyUsageData: ProviderUsageData {
        guard let snap = apiKeySnapshot else {
            return .empty(
                for: .gemini,
                error: error,
                lastRefresh: lastRefresh,
                isLoading: isLoading
            )
        }

        return buildUsageData(
            rpdUtilization: snap.rpdUtilization,
            rpmUtilization: snap.rpmUtilization,
            tier: snap.tier,
            inputTokens: snap.estimatedInputTokens,
            outputTokens: snap.estimatedOutputTokens,
            costToday: snap.estimatedCostToday,
            model: snap.model,
            planSuffix: nil
        )
    }

    // MARK: - Shared Builder

    private func buildUsageData(
        rpdUtilization: Double,
        rpmUtilization: Double,
        tier: GeminiTier,
        inputTokens: Int,
        outputTokens: Int,
        costToday: Double,
        model: String?,
        planSuffix: String?
    ) -> ProviderUsageData {
        // RPD resets at midnight Pacific (approximate with next calendar day)
        let nextMidnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))

        let buckets: [RateBucket] = [
            RateBucket(
                label: "Daily",
                utilization: rpdUtilization,
                resetsAt: nextMidnight,
                isWarning: rpdUtilization >= 70
            ),
            RateBucket(
                label: "Per Min",
                utilization: rpmUtilization,
                resetsAt: nil,
                isWarning: rpmUtilization >= 70
            ),
        ]

        let planName = tier.displayName + (planSuffix ?? "")

        let cost = CostSummary(
            windowCost: costToday,
            windowLabel: "today (est.)",
            dailyCost: costToday,
            dailyLabel: "Today (est.)",
            breakdown: nil
        )

        let tokenBreakdown = TokenBreakdownData(
            title: "Estimated Tokens",
            usage: TokenUsage(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationInputTokens: 0,
                cacheReadInputTokens: 0
            )
        )

        return ProviderUsageData(
            provider: .gemini,
            isAvailable: true,
            usedPercentage: rpdUtilization,
            remainingPercentage: 100.0 - rpdUtilization,
            primaryWindowLabel: "Daily",
            resetsAt: nextMidnight,
            rateLimitBuckets: buckets,
            planName: planName,
            estimatedCost: cost,
            tokenBreakdown: tokenBreakdown,
            enterpriseQuota: nil,
            creditsInfo: nil,
            detailedRateWindows: nil,
            error: error,
            lastRefresh: lastRefresh,
            isLoading: isLoading
        )
    }
}
