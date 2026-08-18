import Foundation

@MainActor
final class DecisionHistoryStore {
    struct FeedbackSummary: Equatable, Sendable {
        let helpful: Int
        let unhelpful: Int
    }

    private struct Sample: Codable {
        let provider: String
        let timestamp: Date
        let remainingPercentage: Double
    }

    private struct FeedbackEvent: Codable {
        let timestamp: Date
        let kind: String
        let provider: String?
        let helpful: Bool
    }

    private enum Key {
        static let samples = "decisionHistory.samples.v1"
        static let feedback = "decisionHistory.feedback.v1"
        static let legacyPendingRun = "decisionHistory.pendingRun.v1"
        static let legacyOutcomes = "decisionHistory.outcomes.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // The explicit Start Medium Task workflow is gone. Removing its old
        // records avoids silently shaping current recommendations with data
        // the user can no longer inspect or correct.
        defaults.removeObject(forKey: Key.legacyPendingRun)
        defaults.removeObject(forKey: Key.legacyOutcomes)
    }

    func record(_ data: ProviderUsageData, now: Date = Date()) {
        guard data.isAvailable, data.error == nil, let refreshedAt = data.lastRefresh else { return }

        var samples = loadSamples()
        if samples.contains(where: { $0.provider == data.provider.rawValue && $0.timestamp == refreshedAt }) {
            return
        }
        if let latest = samples.last(where: { $0.provider == data.provider.rawValue }),
           refreshedAt.timeIntervalSince(latest.timestamp) < 5 * 60 {
            return
        }

        samples.append(Sample(
            provider: data.provider.rawValue,
            timestamp: refreshedAt,
            remainingPercentage: UsageDecisionEngine.headroom(for: data)
        ))
        let cutoff = now.addingTimeInterval(-30 * AppConstants.secondsPerDay)
        samples = samples
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
        if samples.count > 20_000 {
            samples.removeFirst(samples.count - 20_000)
        }
        save(samples, key: Key.samples)
    }

    func recordFeedback(
        helpful: Bool,
        decision: UsageDecision,
        now: Date = Date()
    ) {
        var events = loadFeedback()
        events.append(FeedbackEvent(
            timestamp: now,
            kind: decision.kind.rawValue,
            provider: decision.recommendedProvider?.rawValue,
            helpful: helpful
        ))
        if events.count > 100 {
            events.removeFirst(events.count - 100)
        }
        save(events, key: Key.feedback)
    }

    var feedbackSummary: FeedbackSummary {
        let events = loadFeedback()
        return FeedbackSummary(
            helpful: events.filter(\.helpful).count,
            unhelpful: events.filter { !$0.helpful }.count
        )
    }

    func history(
        for provider: CLIProvider,
        days: Int = 7,
        now: Date = Date()
    ) -> [UsageHistoryPoint] {
        let cutoff = now.addingTimeInterval(-Double(max(days, 1)) * AppConstants.secondsPerDay)
        let points = loadSamples()
            .filter { $0.provider == provider.rawValue && $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
            .map {
                UsageHistoryPoint(
                    timestamp: $0.timestamp,
                    remainingPercentage: $0.remainingPercentage
                )
            }
        guard points.count > 180 else { return points }

        let stride = Int(ceil(Double(points.count) / 180))
        var sampled = points.enumerated().compactMap { index, point in
            index.isMultiple(of: stride) ? point : nil
        }
        if sampled.last != points.last, let last = points.last {
            sampled.append(last)
        }
        return sampled
    }

    func forecast(
        for data: ProviderUsageData,
        now: Date = Date()
    ) -> ProviderHeadroomForecast {
        let recent = history(for: data.provider, days: 1, now: now)
            .filter { $0.timestamp >= now.addingTimeInterval(-6 * 60 * 60) }
        let rates = zip(recent, recent.dropFirst()).compactMap { previous, current -> Double? in
            let interval = current.timestamp.timeIntervalSince(previous.timestamp)
            let consumed = previous.remainingPercentage - current.remainingPercentage
            guard interval > 0, interval <= 30 * 60, consumed >= 0.1, consumed <= 50 else {
                return nil
            }
            return consumed / (interval / 3600)
        }
        .sorted()

        guard rates.count >= 2 else {
            return ProviderHeadroomForecast(
                exhaustionAt: nil,
                consumptionPerHour: 0,
                sampleCount: rates.count,
                resetsBeforeExhaustion: false
            )
        }

        let rate = rates[rates.count / 2]
        let currentHeadroom = UsageDecisionEngine.headroom(for: data)
        let hours = currentHeadroom / max(rate, 0.01)
        let exhaustionAt = now.addingTimeInterval(hours * 3600)
        return ProviderHeadroomForecast(
            exhaustionAt: exhaustionAt,
            consumptionPerHour: rate,
            sampleCount: rates.count,
            resetsBeforeExhaustion: data.resetsAt.map { $0 < exhaustionAt } ?? false
        )
    }

    private func loadSamples() -> [Sample] {
        load([Sample].self, key: Key.samples) ?? []
    }

    private func loadFeedback() -> [FeedbackEvent] {
        load([FeedbackEvent].self, key: Key.feedback) ?? []
    }

    private func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func save<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
