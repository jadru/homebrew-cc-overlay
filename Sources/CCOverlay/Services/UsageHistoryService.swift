import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class UsageHistoryService {
    private let modelContainer: ModelContainer
    private var lastSnapshotHour: [String: Int] = [:]

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Record an hourly snapshot if we haven't recorded one this hour for this provider.
    func recordSnapshot(usage: TokenUsage, cost: CostBreakdown, provider: CLIProvider) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let key = "\(provider.rawValue)-\(calendar.startOfDay(for: Date()))-\(hour)"

        guard lastSnapshotHour[key] == nil else { return }
        lastSnapshotHour[key] = hour

        let snapshot = UsageSnapshot(
            timestamp: Date(),
            provider: provider.rawValue,
            intervalType: "hourly",
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            cacheCreationTokens: usage.cacheCreationInputTokens,
            cacheReadTokens: usage.cacheReadInputTokens,
            totalCost: cost.totalCost
        )

        let context = ModelContext(modelContainer)
        context.insert(snapshot)
        try? context.save()
    }

    /// Fetch daily snapshots for a provider within the last N days.
    func dailySnapshots(for provider: CLIProvider, days: Int = 7) -> [UsageSnapshot] {
        let cutoff = Date().addingTimeInterval(-Double(days) * AppConstants.secondsPerDay)
        let providerName = provider.rawValue
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<UsageSnapshot> {
            $0.provider == providerName && $0.timestamp >= cutoff
        }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.timestamp)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Remove snapshots older than the specified number of days.
    func pruneOldData(olderThan days: Int = 90) {
        let cutoff = Date().addingTimeInterval(-Double(days) * AppConstants.secondsPerDay)
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<UsageSnapshot> {
            $0.timestamp < cutoff
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let old = try? context.fetch(descriptor) else { return }
        for snapshot in old {
            context.delete(snapshot)
        }
        try? context.save()
    }
}
