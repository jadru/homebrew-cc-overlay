import Foundation

/// Normalized usage data that any CLI provider produces for the UI.
struct ProviderUsageData: Sendable {
    let provider: CLIProvider
    let isAvailable: Bool

    // Primary gauge
    let usedPercentage: Double            // 0-100
    let remainingPercentage: Double       // 0-100
    let primaryWindowLabel: String        // "5h" for Claude, "Daily" / "Credits" for Codex
    let resetsAt: Date?

    // Secondary rate limit buckets
    let rateLimitBuckets: [RateBucket]

    // Plan info
    let planName: String?

    // Cost info
    let estimatedCost: CostSummary?

    // Token breakdown (optional)
    let tokenBreakdown: TokenBreakdownData?

    // Enterprise quota (Claude-specific, nil for Codex)
    let enterpriseQuota: EnterpriseQuota?

    // Codex-specific display data (nil for Claude)
    let creditsInfo: CreditsDisplayInfo?
    let detailedRateWindows: [DetailedRateWindow]?

    // State
    let error: String?
    let lastRefresh: Date?
    let isLoading: Bool

    static func empty(
        for provider: CLIProvider,
        error: String? = nil,
        lastRefresh: Date? = nil,
        isLoading: Bool = false
    ) -> ProviderUsageData {
        ProviderUsageData(
            provider: provider,
            isAvailable: false,
            usedPercentage: 0,
            remainingPercentage: 100,
            primaryWindowLabel: provider == .claudeCode ? "5h" : "Daily",
            resetsAt: nil,
            rateLimitBuckets: [],
            planName: nil,
            estimatedCost: nil,
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

// MARK: - Sub-types

struct RateBucket: Sendable, Identifiable {
    let id: String
    let label: String
    let utilization: Double   // 0-100
    let resetsAt: Date?
    let isWarning: Bool

    init(label: String, utilization: Double, resetsAt: Date? = nil, isWarning: Bool = false) {
        self.id = label
        self.label = label
        self.utilization = utilization
        self.resetsAt = resetsAt
        self.isWarning = isWarning
    }
}

struct CostSummary: Sendable {
    let windowCost: Double
    let windowLabel: String       // "5h window" or "today"
    let dailyCost: Double
    let dailyLabel: String        // "Today" or "Monthly"
    let breakdown: CostBreakdown?
}

struct TokenBreakdownData: Sendable {
    let title: String
    let usage: TokenUsage
}

struct CreditsDisplayInfo: Sendable {
    let planType: String
    let hasCredits: Bool
    let unlimited: Bool
    let balance: String?
    let extraUsageEnabled: Bool
}

struct DetailedRateWindow: Sendable, Identifiable {
    let id: String
    let label: String
    let usedPercent: Double        // 0-100
    let remainingPercent: Double   // 0-100
    let windowDuration: String     // "5h", "7d", etc.
    let resetsAt: Date?
    let resetAfterSeconds: Int?
    let isPrimary: Bool
}
