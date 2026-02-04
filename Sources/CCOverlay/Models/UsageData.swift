import Foundation

// MARK: - JSONL Entry Models

struct JournalEntry: Codable, Sendable {
    let type: String?
    let sessionId: String?
    let timestamp: String?
    let message: MessagePayload?
}

struct MessagePayload: Codable, Sendable {
    let model: String?
    let role: String?
    let usage: APIUsage?
}

struct APIUsage: Codable, Sendable {
    let input_tokens: Int?
    let output_tokens: Int?
    let cache_creation_input_tokens: Int?
    let cache_read_input_tokens: Int?
    let service_tier: String?
}

// MARK: - App Domain Models

struct TokenUsage: Sendable, Equatable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationInputTokens + cacheReadInputTokens
    }

    /// Weighted cost in input-token-equivalent units.
    /// Accounts for different pricing per token type:
    /// input=1.0x, output=5.0x, cache_create=1.25x, cache_read=0.1x
    var weightedCost: Double {
        Double(inputTokens) * TokenCostWeight.input
            + Double(outputTokens) * TokenCostWeight.output
            + Double(cacheCreationInputTokens) * TokenCostWeight.cacheCreation
            + Double(cacheReadInputTokens) * TokenCostWeight.cacheRead
    }

    static let zero = TokenUsage(
        inputTokens: 0,
        outputTokens: 0,
        cacheCreationInputTokens: 0,
        cacheReadInputTokens: 0
    )
}

struct ParsedUsageEntry: Sendable {
    let sessionId: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let timestamp: Date
}

struct SessionUsage: Identifiable, Sendable {
    let id: String
    let model: String
    let tokenUsage: TokenUsage
    let messageCount: Int
    let firstTimestamp: Date
    let lastTimestamp: Date
}

struct AggregatedUsage: Sendable {
    let currentSession: SessionUsage?
    let fiveHourWindow: TokenUsage
    let dailyTotal: TokenUsage
    let allSessions: [SessionUsage]
    let fiveHourCost: CostBreakdown
    let dailyCost: CostBreakdown

    static let empty = AggregatedUsage(
        currentSession: nil,
        fiveHourWindow: .zero,
        dailyTotal: .zero,
        allSessions: [],
        fiveHourCost: .zero,
        dailyCost: .zero
    )

    /// Usage percentage based on weighted cost against plan limit.
    func usagePercentage(limit: Double) -> Double {
        guard limit > 0 else { return 0 }
        return min(fiveHourWindow.weightedCost / limit * 100.0, 100.0)
    }

    /// Remaining weighted cost units.
    func remainingCost(limit: Double) -> Double {
        max(limit - fiveHourWindow.weightedCost, 0)
    }
}

// MARK: - OAuth Usage API Response (from GET /api/oauth/usage)

struct UsageBucket: Sendable {
    let utilization: Double   // 0-100 (percentage)
    let resetsAt: Date?

    static let zero = UsageBucket(utilization: 0, resetsAt: nil)
}

struct OAuthUsageStatus: Sendable {
    let fiveHour: UsageBucket
    let sevenDay: UsageBucket
    let sevenDaySonnet: UsageBucket?
    let extraUsageEnabled: Bool
    let fetchedAt: Date

    static let empty = OAuthUsageStatus(
        fiveHour: .zero,
        sevenDay: .zero,
        sevenDaySonnet: nil,
        extraUsageEnabled: false,
        fetchedAt: .distantPast
    )

    /// Primary display percentage: always the 5-hour session window.
    var usedPercentage: Double {
        min(fiveHour.utilization, 100.0)
    }

    var remainingPercentage: Double {
        100.0 - usedPercentage
    }

    /// The primary display window is always the session window.
    var primaryWindow: String { "five_hour" }

    /// Reset time for the primary (5-hour session) window.
    var primaryResetsAt: Date? {
        fiveHour.resetsAt
    }

    /// Threshold at which the weekly limit becomes prominent.
    static let weeklyWarningThreshold: Double = 70.0

    /// True when the weekly limit is nearing exhaustion.
    var isWeeklyNearLimit: Bool {
        sevenDay.utilization >= Self.weeklyWarningThreshold
    }

    var isAvailable: Bool {
        fetchedAt != .distantPast
    }
}
