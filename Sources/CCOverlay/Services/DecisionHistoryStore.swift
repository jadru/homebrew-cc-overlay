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
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func record(_ data: ProviderUsageData, now: Date = Date()) {
        guard data.isAvailable, data.error == nil, let refreshedAt = data.lastRefresh else { return }

        var samples = loadSamples()
        if samples.contains(where: { $0.provider == data.provider.rawValue && $0.timestamp == refreshedAt }) {
            return
        }

        samples.append(Sample(
            provider: data.provider.rawValue,
            timestamp: refreshedAt,
            remainingPercentage: UsageDecisionEngine.headroom(for: data)
        ))
        let cutoff = now.addingTimeInterval(-7 * AppConstants.secondsPerDay)
        samples = samples
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
        if samples.count > 600 {
            samples.removeFirst(samples.count - 600)
        }
        save(samples, key: Key.samples)
    }

    func evidence(
        for provider: CLIProvider,
        taskSize: PlannedTaskSize,
        now: Date = Date()
    ) -> TaskFitEvidence? {
        let cutoff = now.addingTimeInterval(-7 * AppConstants.secondsPerDay)
        let providerSamples = loadSamples()
            .filter { $0.provider == provider.rawValue && $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }

        let deltas = zip(providerSamples, providerSamples.dropFirst()).compactMap { previous, current -> Double? in
            let interval = current.timestamp.timeIntervalSince(previous.timestamp)
            let consumed = previous.remainingPercentage - current.remainingPercentage
            guard interval > 0, interval <= 30 * 60, consumed >= 0.25, consumed <= 50 else { return nil }
            return consumed
        }
        .sorted()

        guard deltas.count >= 3 else { return nil }

        let percentile: Double
        let multiplier: Double
        switch taskSize {
        case .small:
            percentile = 0.25
            multiplier = 1.0
        case .medium:
            percentile = 0.50
            multiplier = 1.5
        case .large:
            percentile = 0.90
            multiplier = 2.0
        }

        let index = min(Int((Double(deltas.count - 1) * percentile).rounded()), deltas.count - 1)
        let required = min(max(deltas[index] * multiplier, 1), 90)
        return TaskFitEvidence(requiredHeadroom: required, sampleCount: deltas.count)
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
