import Foundation
import Observation

@Observable
@MainActor
final class GeminiProviderService: BaseProviderService {
    private var oauthService: GeminiOAuthService?
    private var detection: GeminiDetector.Detection?
    private var oauthSnapshot: GeminiUsageSnapshot?

    init() {
        super.init(provider: .gemini)
    }

    // MARK: - Detection

    /// Detect Gemini CLI binary and auth credentials (OAuth only).
    func detect() async -> Bool {
        detection = GeminiDetector.detect()
        setDetected(detection?.binaryPath != nil)

        switch detection?.authMode {
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
        await fetchOAuthUsage()
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

    // MARK: - Usage Data

    override var usageData: ProviderUsageData {
        return oauthUsageData
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
            isDetected: isDetected,
            isAuthenticated: isAuthenticated,
            lastActivityAt: lastActivityAt,
            lastSuccessfulRefresh: lastSuccessfulRefresh,
            lastResponseDuration: lastResponseDuration,
            error: error,
            lastRefresh: lastRefresh,
            isLoading: isLoading
        )
    }
}
