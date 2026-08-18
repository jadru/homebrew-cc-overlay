import Foundation

@MainActor
final class DecisionHistoryStore {
    struct FeedbackSummary: Equatable, Sendable {
        let helpful: Int
        let unhelpful: Int
    }

    struct OutcomeSummary: Equatable, Sendable {
        let completed: Int
        let hitLimit: Int
        let switched: Int
        let usedReset: Int
        let cancelled: Int
    }

    struct CalibrationSummary: Equatable, Sendable {
        let likelyFitRuns: Int
        let likelyFitLimitHits: Int

        var falseSafeRate: Double? {
            guard likelyFitRuns > 0 else { return nil }
            return Double(likelyFitLimitHits) / Double(likelyFitRuns)
        }
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

    private struct OutcomeEvent: Codable {
        let timestamp: Date
        let provider: CLIProvider
        let taskSize: PlannedTaskSize
        let outcome: RunOutcome
        let startingHeadroom: Double
        let endingHeadroom: Double
        let decisionConfidence: UsageDecision.Confidence?
        let taskFitOutcome: TaskFitAssessment.Outcome?
        let dataQuality: UsageDecision.DataQuality?
    }

    private enum Key {
        static let samples = "decisionHistory.samples.v1"
        static let feedback = "decisionHistory.feedback.v1"
        static let pendingRun = "decisionHistory.pendingRun.v1"
        static let outcomes = "decisionHistory.outcomes.v1"
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

    func evidence(
        for provider: CLIProvider,
        taskSize: PlannedTaskSize,
        now: Date = Date()
    ) -> TaskFitEvidence? {
        let cutoff = now.addingTimeInterval(-7 * AppConstants.secondsPerDay)
        let outcomeDeltas = loadOutcomes()
            .filter {
                $0.provider == provider
                    && $0.taskSize == taskSize
                    && $0.timestamp >= cutoff
            }
            .compactMap { event -> Double? in
                switch event.outcome {
                case .completed:
                    let consumed = event.startingHeadroom - event.endingHeadroom
                    return consumed >= 0.25 ? min(consumed, 90) : nil
                case .hitLimit:
                    return min(max(event.startingHeadroom * 1.1, 1), 90)
                case .switchedProvider, .usedReset, .cancelled:
                    return nil
                }
            }

        let deltas = outcomeDeltas.sorted()

        guard !deltas.isEmpty else { return nil }

        let percentile: Double
        switch taskSize {
        case .small:
            percentile = 0.75
        case .medium:
            percentile = 0.80
        case .large:
            percentile = 0.90
        }

        let index = min(Int((Double(deltas.count - 1) * percentile).rounded()), deltas.count - 1)
        let required = min(max(deltas[index], 1), 90)
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

    func beginRun(
        decision: UsageDecision,
        taskSize: PlannedTaskSize,
        projectName: String?,
        now: Date = Date()
    ) -> PendingRun? {
        guard let provider = decision.recommendedProvider else { return nil }
        let run = PendingRun(
            id: UUID(),
            startedAt: now,
            provider: provider,
            taskSize: taskSize,
            startingHeadroom: decision.recommendedHeadroom ?? 0,
            projectName: projectName,
            decisionConfidence: decision.confidence,
            taskFitOutcome: decision.taskFit?.outcome,
            dataQuality: decision.dataQuality
        )
        save(run, key: Key.pendingRun)
        return run
    }

    var pendingRun: PendingRun? {
        load(PendingRun.self, key: Key.pendingRun)
    }

    func completePendingRun(
        outcome: RunOutcome,
        endingHeadroom: Double,
        now: Date = Date()
    ) {
        guard let run = pendingRun else { return }
        var outcomes = loadOutcomes()
        outcomes.append(OutcomeEvent(
            timestamp: now,
            provider: run.provider,
            taskSize: run.taskSize,
            outcome: outcome,
            startingHeadroom: run.startingHeadroom,
            endingHeadroom: max(0, min(endingHeadroom, 100)),
            decisionConfidence: run.decisionConfidence,
            taskFitOutcome: run.taskFitOutcome,
            dataQuality: run.dataQuality
        ))
        let cutoff = now.addingTimeInterval(-90 * AppConstants.secondsPerDay)
        outcomes = outcomes.filter { $0.timestamp >= cutoff }
        if outcomes.count > 500 {
            outcomes.removeFirst(outcomes.count - 500)
        }
        save(outcomes, key: Key.outcomes)
        defaults.removeObject(forKey: Key.pendingRun)
    }

    var outcomeSummary: OutcomeSummary {
        let outcomes = loadOutcomes()
        return OutcomeSummary(
            completed: outcomes.filter { $0.outcome == .completed }.count,
            hitLimit: outcomes.filter { $0.outcome == .hitLimit }.count,
            switched: outcomes.filter { $0.outcome == .switchedProvider }.count,
            usedReset: outcomes.filter { $0.outcome == .usedReset }.count,
            cancelled: outcomes.filter { $0.outcome == .cancelled }.count
        )
    }

    var calibrationSummary: CalibrationSummary {
        let comparable = loadOutcomes().filter {
            $0.taskFitOutcome == .likely
                && ($0.outcome == .completed || $0.outcome == .hitLimit)
        }
        return CalibrationSummary(
            likelyFitRuns: comparable.count,
            likelyFitLimitHits: comparable.filter { $0.outcome == .hitLimit }.count
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

    private func loadOutcomes() -> [OutcomeEvent] {
        load([OutcomeEvent].self, key: Key.outcomes) ?? []
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
