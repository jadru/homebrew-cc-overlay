import Foundation
import XCTest

@testable import Amarillo

final class UsageCalculatorTests: XCTestCase {

    private func makeEntry(
        sessionId: String = "test",
        inputTokens: Int = 100,
        outputTokens: Int = 50,
        cacheCreation: Int = 0,
        cacheRead: Int = 0,
        timestamp: Date = Date()
    ) -> ParsedUsageEntry {
        ParsedUsageEntry(
            sessionId: sessionId,
            model: "claude-opus-4-5-20251101",
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreation,
            cacheReadTokens: cacheRead,
            timestamp: timestamp
        )
    }

    func testSumTokens() {
        let entries = [
            makeEntry(inputTokens: 100, outputTokens: 50, cacheCreation: 200, cacheRead: 300),
            makeEntry(inputTokens: 10, outputTokens: 5, cacheCreation: 20, cacheRead: 30),
        ]

        let total = UsageCalculator.sumTokens(entries)

        XCTAssertEqual(total.inputTokens, 110)
        XCTAssertEqual(total.outputTokens, 55)
        XCTAssertEqual(total.cacheCreationInputTokens, 220)
        XCTAssertEqual(total.cacheReadInputTokens, 330)
        XCTAssertEqual(total.totalTokens, 715)
    }

    func testFiveHourWindowFilter() {
        let now = Date()
        let entries = [
            makeEntry(timestamp: now.addingTimeInterval(-1 * 60 * 60)),   // 1hr ago — in
            makeEntry(timestamp: now.addingTimeInterval(-4 * 60 * 60)),   // 4hr ago — in
            makeEntry(timestamp: now.addingTimeInterval(-6 * 60 * 60)),   // 6hr ago — out
            makeEntry(timestamp: now.addingTimeInterval(-24 * 60 * 60)),  // 24hr ago — out
        ]

        let windowEntries = UsageCalculator.fiveHourWindowEntries(from: entries, now: now)
        XCTAssertEqual(windowEntries.count, 2)
    }

    func testTodayEntriesFilter() {
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        let entries = [
            makeEntry(timestamp: startOfToday.addingTimeInterval(1 * 60 * 60)),   // today
            makeEntry(timestamp: startOfToday.addingTimeInterval(5 * 60 * 60)),   // today
            makeEntry(timestamp: startOfToday.addingTimeInterval(-1 * 60 * 60)),  // yesterday
        ]

        let todayResults = UsageCalculator.todayEntries(from: entries, now: now)
        XCTAssertEqual(todayResults.count, 2)
    }

    func testAggregateGroupsBySession() {
        let now = Date()
        let entries = [
            makeEntry(sessionId: "session-a", inputTokens: 100,
                      timestamp: now.addingTimeInterval(-1 * 60 * 60)),
            makeEntry(sessionId: "session-a", inputTokens: 200,
                      timestamp: now.addingTimeInterval(-30 * 60)),
            makeEntry(sessionId: "session-b", inputTokens: 300, timestamp: now),
        ]

        let aggregated = UsageCalculator.aggregate(entries: entries, now: now)

        XCTAssertEqual(aggregated.allSessions.count, 2)
        XCTAssertEqual(aggregated.currentSession?.id, "session-b")
    }

    func testEmptyAggregation() {
        let aggregated = UsageCalculator.aggregate(entries: [])

        XCTAssertTrue(aggregated.allSessions.isEmpty)
        XCTAssertNil(aggregated.currentSession)
        XCTAssertEqual(aggregated.fiveHourWindow.totalTokens, 0)
        XCTAssertEqual(aggregated.dailyTotal.totalTokens, 0)
    }

    func testWeightedCost() {
        let usage = TokenUsage(
            inputTokens: 1000, outputTokens: 100,
            cacheCreationInputTokens: 200, cacheReadInputTokens: 10000
        )
        // 1000*1.0 + 100*5.0 + 200*1.25 + 10000*0.1 = 1000 + 500 + 250 + 1000 = 2750
        XCTAssertEqual(usage.weightedCost, 2750.0, accuracy: 0.01)
    }

    func testCacheReadWeightedMuchLess() {
        // Cache read tokens are 0.1x weight — verifies the key fix
        let heavyCacheRead = TokenUsage(
            inputTokens: 100, outputTokens: 50,
            cacheCreationInputTokens: 0, cacheReadInputTokens: 40_000_000
        )
        // Raw: 40,000,150. Weighted: 100*1 + 50*5 + 0 + 40M*0.1 = 100 + 250 + 4M = ~4,000,350
        XCTAssertEqual(heavyCacheRead.totalTokens, 40_000_150)
        XCTAssertEqual(heavyCacheRead.weightedCost, 4_000_350.0, accuracy: 0.01)
        // Weighted is ~0.1x of raw total
        XCTAssertTrue(heavyCacheRead.weightedCost < Double(heavyCacheRead.totalTokens) * 0.2)
    }

    func testUsagePercentageWithWeightedCost() {
        let usage = AggregatedUsage(
            currentSession: nil,
            fiveHourWindow: TokenUsage(
                inputTokens: 2_500_000, outputTokens: 0,
                cacheCreationInputTokens: 0, cacheReadInputTokens: 0
            ),
            dailyTotal: .zero,
            allSessions: [],
            fiveHourCost: .zero,
            dailyCost: .zero
        )
        // 2.5M input at 1.0x = 2.5M weighted. Limit 5M → 50%
        XCTAssertEqual(usage.usagePercentage(limit: 5_000_000), 50.0)
    }

    func testUsagePercentageCappedAt100() {
        let usage = AggregatedUsage(
            currentSession: nil,
            fiveHourWindow: TokenUsage(
                inputTokens: 10_000_000, outputTokens: 0,
                cacheCreationInputTokens: 0, cacheReadInputTokens: 0
            ),
            dailyTotal: .zero,
            allSessions: [],
            fiveHourCost: .zero,
            dailyCost: .zero
        )
        // 10M weighted > 5M limit → capped at 100%
        XCTAssertEqual(usage.usagePercentage(limit: 5_000_000), 100.0)
    }

    func testRemainingCost() {
        let usage = AggregatedUsage(
            currentSession: nil,
            fiveHourWindow: TokenUsage(
                inputTokens: 1_000_000, outputTokens: 0,
                cacheCreationInputTokens: 0, cacheReadInputTokens: 0
            ),
            dailyTotal: .zero,
            allSessions: [],
            fiveHourCost: .zero,
            dailyCost: .zero
        )
        // 1M weighted used, 5M limit → 4M remaining
        XCTAssertEqual(usage.remainingCost(limit: 5_000_000), 4_000_000, accuracy: 0.01)
    }
}
