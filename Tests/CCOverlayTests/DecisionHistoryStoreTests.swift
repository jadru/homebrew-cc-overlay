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
            let timestamp = start.addingTimeInterval(Double(index) * 60)
            store.record(data(remaining: remaining, refreshedAt: timestamp), now: timestamp)
        }

        let evidence = store.evidence(for: .codex, taskSize: .medium, now: start.addingTimeInterval(240))
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
