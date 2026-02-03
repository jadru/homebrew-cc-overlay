import Foundation

struct UsageCalculator: Sendable {

    /// Filter entries within the 5-hour billing window from now.
    static func fiveHourWindowEntries(from entries: [ParsedUsageEntry], now: Date = Date()) -> [ParsedUsageEntry] {
        let cutoff = now.addingTimeInterval(-AppConstants.fiveHourWindowSeconds)
        return entries.filter { $0.timestamp >= cutoff }
    }

    /// Filter entries from today.
    static func todayEntries(from entries: [ParsedUsageEntry], now: Date = Date()) -> [ParsedUsageEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
    }

    /// Aggregate all entries into a summary.
    static func aggregate(entries: [ParsedUsageEntry], now: Date = Date()) -> AggregatedUsage {
        let windowEntries = fiveHourWindowEntries(from: entries, now: now)
        let dailyEntries = todayEntries(from: entries, now: now)

        let windowUsage = sumTokens(windowEntries)
        let dailyUsage = sumTokens(dailyEntries)

        let sessionGroups = Dictionary(grouping: entries) { $0.sessionId }
        let sessions = sessionGroups.map { id, sessionEntries in
            SessionUsage(
                id: id,
                model: sessionEntries.first?.model ?? "unknown",
                tokenUsage: sumTokens(sessionEntries),
                messageCount: sessionEntries.count,
                firstTimestamp: sessionEntries.map(\.timestamp).min() ?? now,
                lastTimestamp: sessionEntries.map(\.timestamp).max() ?? now
            )
        }.sorted { $0.lastTimestamp > $1.lastTimestamp }

        let windowCost = CostCalculator.cost(for: windowEntries)
        let dailyCost = CostCalculator.cost(for: dailyEntries)

        return AggregatedUsage(
            currentSession: sessions.first,
            fiveHourWindow: windowUsage,
            dailyTotal: dailyUsage,
            allSessions: sessions,
            fiveHourCost: windowCost,
            dailyCost: dailyCost
        )
    }

    static func sumTokens(_ entries: [ParsedUsageEntry]) -> TokenUsage {
        TokenUsage(
            inputTokens: entries.reduce(0) { $0 + $1.inputTokens },
            outputTokens: entries.reduce(0) { $0 + $1.outputTokens },
            cacheCreationInputTokens: entries.reduce(0) { $0 + $1.cacheCreationTokens },
            cacheReadInputTokens: entries.reduce(0) { $0 + $1.cacheReadTokens }
        )
    }
}
