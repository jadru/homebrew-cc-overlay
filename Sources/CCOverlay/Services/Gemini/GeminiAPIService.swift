import Foundation

/// Tracks Gemini CLI usage when authenticated via API key.
/// Since Gemini has no remote usage API, data comes from local telemetry.
actor GeminiAPIService {
    private var apiKey: String?
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
        let model: String?
        let fetchedAt: Date
    }

    init() {
        self.telemetryParser = GeminiTelemetryParser()
    }

    func configure(apiKey: String) {
        self.apiKey = apiKey
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard apiKey != nil else {
            throw GeminiServiceError.noAPIKey
        }

        let usage = await telemetryParser.parseUsage()
        return buildSnapshot(from: usage)
    }

    private func buildSnapshot(from usage: GeminiTelemetryParser.UsageEstimate) -> UsageSnapshot {
        // API key mode uses Developer API rate limits (much lower than Code Assist)
        let tier: GeminiTier = .apiFree
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
            model: model,
            fetchedAt: Date()
        )
    }
}

// MARK: - Errors

enum GeminiServiceError: LocalizedError {
    case noAPIKey
    case noAuth

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Gemini API key not configured"
        case .noAuth: return "Gemini not authenticated"
        }
    }
}
