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

    static func claudeProjectEntries(from entries: [ParsedUsageEntry]) -> [ProjectUsageEntry] {
        entries.compactMap { entry in
            guard let projectName = entry.projectName?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !projectName.isEmpty
            else {
                return nil
            }

            return ProjectUsageEntry(
                provider: .claudeCode,
                source: .claudeLocalEstimate,
                sessionId: entry.sessionId,
                projectName: projectName,
                model: entry.model,
                timestamp: entry.timestamp,
                tokenUsage: TokenUsage(
                    inputTokens: entry.inputTokens,
                    outputTokens: entry.outputTokens,
                    cacheCreationInputTokens: entry.cacheCreationTokens,
                    cacheReadInputTokens: entry.cacheReadTokens
                ),
                claudeEstimatedCost: CostCalculator.cost(for: entry)
            )
        }
    }

    /// Creates compact cross-provider project cards for the last 24 hours.
    static func aggregateProjectUsage(
        entries: [ProjectUsageEntry],
        now: Date = Date()
    ) -> [ProjectUsageSummary] {
        let cutoff = now.addingTimeInterval(-24 * 60 * 60)
        let recentEntries = entries.filter { $0.timestamp >= cutoff }
        let grouped = Dictionary(grouping: recentEntries, by: \.projectName)

        return grouped.map { projectName, projectEntries in
            let tokenUsage = sumProjectTokens(projectEntries)
            let providers = CLIProvider.productOrder.filter { provider in
                projectEntries.contains { $0.provider == provider }
            }
            let sources = [ProjectUsageSource.claudeLocalEstimate, .codexLocalTokens].filter { source in
                projectEntries.contains { $0.source == source }
            }
            let claudeCosts = projectEntries.compactMap(\.claudeEstimatedCost)
            let sessionIDs = Set(projectEntries.map { "\($0.provider.rawValue):\($0.sessionId)" })

            return ProjectUsageSummary(
                projectName: projectName,
                tokenUsage: tokenUsage,
                sessionCount: sessionIDs.count,
                providers: providers,
                sources: sources,
                claudeEstimatedCost: claudeCosts.isEmpty ? nil : claudeCosts.reduce(.zero, +)
            )
        }
        .sorted { lhs, rhs in
            if lhs.tokenUsage.totalTokens != rhs.tokenUsage.totalTokens {
                return lhs.tokenUsage.totalTokens > rhs.tokenUsage.totalTokens
            }
            return lhs.projectName.localizedStandardCompare(rhs.projectName) == .orderedAscending
        }
    }

    private static func sumProjectTokens(_ entries: [ProjectUsageEntry]) -> TokenUsage {
        TokenUsage(
            inputTokens: entries.reduce(0) { $0 + $1.tokenUsage.inputTokens },
            outputTokens: entries.reduce(0) { $0 + $1.tokenUsage.outputTokens },
            cacheCreationInputTokens: entries.reduce(0) { $0 + $1.tokenUsage.cacheCreationInputTokens },
            cacheReadInputTokens: entries.reduce(0) { $0 + $1.tokenUsage.cacheReadInputTokens }
        )
    }
}
