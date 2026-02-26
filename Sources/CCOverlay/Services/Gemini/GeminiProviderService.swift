import Foundation
import Observation

@Observable
@MainActor
final class GeminiProviderService: BaseProviderService {
    private let apiKeyService = GeminiAPIService()
    private var oauthService: GeminiOAuthService?
    private var detection: GeminiDetector.Detection?
    private var apiKeySnapshot: GeminiAPIService.UsageSnapshot?
    private var oauthSnapshot: GeminiOAuthService.UsageSnapshot?

    /// Whether we're using Google OAuth instead of API key
    private var isOAuthMode: Bool { detection?.googleAuth != nil }

    init() {
        super.init(provider: .gemini)
    }

    // MARK: - Detection

    /// Detect Gemini CLI binary and auth credentials.
    /// Supports both Google OAuth and API key modes.
    func detect(manualAPIKey: String? = nil) async -> Bool {
        detection = GeminiDetector.detect(manualAPIKey: manualAPIKey)
        setDetected(detection?.binaryPath != nil)

        switch detection?.authMode {
        case .apiKey(let key):
            setAuthenticated(true)
            await apiKeyService.configure(apiKey: key)
            oauthService = nil
        case .googleOAuth(let auth):
            setAuthenticated(true)
            if let existing = oauthService {
                await existing.updateAuth(auth)
            } else {
                oauthService = GeminiOAuthService(auth: auth)
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
            trackActivity(newUsedPct: snap.rpdUtilization)
            self.oauthSnapshot = snap
            markRefreshed()
        } catch {
            if self.oauthSnapshot == nil {
                setError(error.localizedDescription)
            }
        }
    }

    private func fetchAPIKeyUsage() async {
        do {
            let snap = try await apiKeyService.fetchUsage()
            trackActivity(newUsedPct: snap.rpdUtilization)
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

    private var oauthUsageData: ProviderUsageData {
        guard let snap = oauthSnapshot else {
            return .empty(for: .gemini, error: error, lastRefresh: lastRefresh, isLoading: isLoading)
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

    private var apiKeyUsageData: ProviderUsageData {
        guard let snap = apiKeySnapshot else {
            return .empty(for: .gemini, error: error, lastRefresh: lastRefresh, isLoading: isLoading)
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
        let nextMidnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(AppConstants.secondsPerDay))

        let buckets: [RateBucket] = [
            RateBucket(
                label: "Daily",
                utilization: rpdUtilization,
                resetsAt: nextMidnight,
                isWarning: rpdUtilization >= AppConstants.warningThresholdPct
            ),
            RateBucket(
                label: "Per Min",
                utilization: rpmUtilization,
                resetsAt: nil,
                isWarning: rpmUtilization >= AppConstants.warningThresholdPct
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
            lastActivityAt: lastActivityAt,
            error: error,
            lastRefresh: lastRefresh,
            isLoading: isLoading
        )
    }
}
