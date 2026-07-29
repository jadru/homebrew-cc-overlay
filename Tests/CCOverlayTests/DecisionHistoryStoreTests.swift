import XCTest
@testable import CCOverlay

@MainActor
final class DecisionHistoryStoreTests: XCTestCase {
    func testLearnsTaskHeadroomFromRecentConsumptionBursts() {
        let suiteName = "DecisionHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DecisionHistoryStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for (index, remaining) in [90.0, 85.0, 80.0, 70.0].enumerated() {
            let timestamp = start.addingTimeInterval(Double(index) * 300)
            store.record(data(remaining: remaining, refreshedAt: timestamp), now: timestamp)
        }

        let evidence = store.evidence(for: .codex, taskSize: .medium, now: start.addingTimeInterval(1_200))
        XCTAssertEqual(evidence?.sampleCount, 3)
        XCTAssertEqual(evidence?.requiredHeadroom ?? 0, 7.5, accuracy: 0.01)
    }

    func testStoresOnlyFeedbackCountsForDiagnostics() {
        let suiteName = "DecisionHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DecisionHistoryStore(defaults: defaults)
        let decision = UsageDecision(
            kind: .run,
            title: "Run on Codex",
            detail: "Healthy",
            recommendedProvider: .codex,
            resetAt: nil
        )

        store.recordFeedback(helpful: true, decision: decision)
        store.recordFeedback(helpful: false, decision: decision)
        store.recordFeedback(helpful: true, decision: decision)

        XCTAssertEqual(store.feedbackSummary, .init(helpful: 2, unhelpful: 1))
    }

    func testCompletedRunOutcomesContributeToTaskFitEvidence() {
        let suiteName = "DecisionHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DecisionHistoryStore(defaults: defaults)
        let decision = UsageDecision(
            kind: .run,
            title: "Run",
            detail: "Healthy",
            recommendedProvider: .codex,
            resetAt: nil,
            recommendedHeadroom: 30
        )

        for index in 0..<3 {
            _ = store.beginRun(
                decision: decision,
                taskSize: .medium,
                projectName: "project",
                now: Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
            )
            store.completePendingRun(
                outcome: .completed,
                endingHeadroom: 20,
                now: Date(timeIntervalSince1970: 1_700_000_100 + Double(index))
            )
        }

        let evidence = store.evidence(
            for: .codex,
            taskSize: .medium,
            now: Date(timeIntervalSince1970: 1_700_000_200)
        )
        XCTAssertEqual(evidence?.sampleCount, 3)
        XCTAssertEqual(evidence?.requiredHeadroom ?? 0, 15, accuracy: 0.01)
        XCTAssertEqual(store.outcomeSummary.completed, 3)
        XCTAssertNil(store.pendingRun)
    }

    func testHeadroomHistoryProducesActivePaceForecast() {
        let suiteName = "DecisionHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DecisionHistoryStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for (index, remaining) in [80.0, 70.0, 60.0].enumerated() {
            let timestamp = start.addingTimeInterval(Double(index) * 600)
            store.record(data(remaining: remaining, refreshedAt: timestamp), now: timestamp)
        }
        let now = start.addingTimeInterval(1_200)
        let current = ProviderUsageData(
            provider: .codex,
            isAvailable: true,
            usedPercentage: 40,
            remainingPercentage: 60,
            primaryWindowLabel: "5h",
            resetsAt: now.addingTimeInterval(1_800),
            lastRefresh: now
        )

        let forecast = store.forecast(for: current, now: now)

        XCTAssertEqual(store.history(for: .codex, now: now).count, 3)
        XCTAssertEqual(forecast.sampleCount, 2)
        XCTAssertEqual(forecast.consumptionPerHour, 60, accuracy: 0.01)
        XCTAssertTrue(forecast.resetsBeforeExhaustion)
    }

    private func data(remaining: Double, refreshedAt: Date) -> ProviderUsageData {
        ProviderUsageData(
            provider: .codex,
            isAvailable: true,
            usedPercentage: 100 - remaining,
            remainingPercentage: remaining,
            primaryWindowLabel: "5h",
            rateLimitBuckets: [RateBucket(label: "5h", utilization: 100 - remaining)],
            lastRefresh: refreshedAt
        )
    }
}
