import Foundation

/// Tracks Gemini CLI usage when authenticated via Google OAuth.
/// Since Gemini has no remote usage API, data comes from local telemetry.
actor GeminiOAuthService {
    private var accountEmail: String?
    private let telemetryParser: GeminiTelemetryParser

    struct UsageSnapshot: Sendable {
        let tier: GeminiTier
        let rpmUtilization: Double   // 0-100
        let rpdUtilization: Double   // 0-100
        let estimatedInputTokens: Int
        let estimatedOutputTokens: Int
        let estimatedCostToday: Double
        let requestCount: Int
        let sessionCount: Int
        let accountEmail: String?
        let model: String?
        let fetchedAt: Date
    }

    init(auth: GeminiDetector.GoogleAuth) {
        self.accountEmail = auth.accountEmail
        self.telemetryParser = GeminiTelemetryParser()
    }

    func updateAuth(_ auth: GeminiDetector.GoogleAuth) {
        self.accountEmail = auth.accountEmail
    }

    /// Infer Code Assist tier from email domain.
    /// Personal Gmail accounts are eligible for the free tier.
    /// Workspace (custom domain) accounts need org-purchased Standard/Enterprise — tier is unknown locally.
    private func inferTierFromEmail(_ email: String?) -> GeminiTier {
        guard let email, !email.isEmpty else { return .codeAssistUnknown }
        let domain = email.components(separatedBy: "@").last?.lowercased() ?? ""
        if domain == "gmail.com" || domain == "googlemail.com" {
            return .codeAssistFree
        }
        return .codeAssistUnknown
    }

    func fetchUsage() async throws -> UsageSnapshot {
        let usage = await telemetryParser.parseUsage()

        // Determine tier based on email domain:
        // - @gmail.com / @googlemail.com → likely Free (personal account)
        // - Other domains → Workspace account, tier unknown (could be Standard/Enterprise or ineligible)
        let tier: GeminiTier = inferTierFromEmail(accountEmail)
        let (rpmLimit, rpdLimit) = tier.limits

        let rpmUtil = rpmLimit > 0 ? min((usage.rpmEstimate / Double(rpmLimit)) * 100.0, 100.0) : 0
        let rpdUtil = rpdLimit > 0 ? min((usage.rpdEstimate / Double(rpdLimit)) * 100.0, 100.0) : 0

        let model = usage.model ?? "gemini-2.5-pro"
        let cost = GeminiCostCalculator.calculateCost(
            inputTokens: usage.estimatedTokensInput,
            outputTokens: usage.estimatedTokensOutput,
            model: model
        )

        return UsageSnapshot(
            tier: tier,
            rpmUtilization: rpmUtil,
            rpdUtilization: rpdUtil,
            estimatedInputTokens: usage.estimatedTokensInput,
            estimatedOutputTokens: usage.estimatedTokensOutput,
            estimatedCostToday: cost.totalCost,
            requestCount: usage.requestCount,
            sessionCount: usage.sessionCount,
            accountEmail: accountEmail,
            model: model,
            fetchedAt: Date()
        )
    }
}
