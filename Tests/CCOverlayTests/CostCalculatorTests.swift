import Foundation
import XCTest

@testable import CCOverlay

final class CostCalculatorTests: XCTestCase {

    func testSonnetPricingLookup() {
        let p = CostCalculator.pricing(for: "claude-sonnet-4-20250514")
        XCTAssertEqual(p.inputPerMTok, 3.0)
        XCTAssertEqual(p.outputPerMTok, 15.0)
        XCTAssertEqual(p.cacheWritePerMTok, 3.75)
        XCTAssertEqual(p.cacheReadPerMTok, 0.30)
    }

    func testOpusPricingLookup() {
        let p = CostCalculator.pricing(for: "claude-opus-4-5-20251101")
        XCTAssertEqual(p.inputPerMTok, 15.0)
        XCTAssertEqual(p.outputPerMTok, 75.0)
    }

    func testHaikuPricingLookup() {
        let p = CostCalculator.pricing(for: "claude-3-5-haiku-20250307")
        XCTAssertEqual(p.inputPerMTok, 0.80)
        XCTAssertEqual(p.outputPerMTok, 4.0)
    }

    func testUnknownModelFallsBackToSonnet() {
        let p = CostCalculator.pricing(for: "unknown-model-v1")
        XCTAssertEqual(p.inputPerMTok, 3.0)
    }

    func testSingleEntryCost() {
        let entry = ParsedUsageEntry(
            sessionId: "test", model: "claude-sonnet-4-20250514",
            inputTokens: 1_000_000, outputTokens: 100_000,
            cacheCreationTokens: 0, cacheReadTokens: 0,
            timestamp: Date()
        )
        let cost = CostCalculator.cost(for: entry)
        XCTAssertEqual(cost.inputCost, 3.0, accuracy: 0.001)
        XCTAssertEqual(cost.outputCost, 1.5, accuracy: 0.001)
        XCTAssertEqual(cost.totalCost, 4.5, accuracy: 0.001)
    }

    func testMixedModelCost() {
        let entries = [
            ParsedUsageEntry(
                sessionId: "s1", model: "claude-opus-4-5-20251101",
                inputTokens: 1_000_000, outputTokens: 50_000,
                cacheCreationTokens: 0, cacheReadTokens: 0, timestamp: Date()
            ),
            ParsedUsageEntry(
                sessionId: "s2", model: "claude-sonnet-4-20250514",
                inputTokens: 1_000_000, outputTokens: 50_000,
                cacheCreationTokens: 0, cacheReadTokens: 0, timestamp: Date()
            ),
        ]
        let cost = CostCalculator.cost(for: entries)
        // Opus: 1M*$15 + 50K*$75 = $15 + $3.75 = $18.75
        // Sonnet: 1M*$3 + 50K*$15 = $3 + $0.75 = $3.75
        XCTAssertEqual(cost.totalCost, 22.5, accuracy: 0.001)
    }

    func testCacheTokenCosts() {
        let entry = ParsedUsageEntry(
            sessionId: "test", model: "claude-sonnet-4-20250514",
            inputTokens: 0, outputTokens: 0,
            cacheCreationTokens: 1_000_000, cacheReadTokens: 10_000_000,
            timestamp: Date()
        )
        let cost = CostCalculator.cost(for: entry)
        XCTAssertEqual(cost.cacheWriteCost, 3.75, accuracy: 0.001)
        XCTAssertEqual(cost.cacheReadCost, 3.0, accuracy: 0.001)
    }

    func testZeroCost() {
        let cost = CostCalculator.cost(for: [] as [ParsedUsageEntry])
        XCTAssertEqual(cost.totalCost, 0)
        XCTAssertEqual(cost, .zero)
    }

    func testCostBreakdownAddition() {
        let a = CostBreakdown(inputCost: 1.0, outputCost: 2.0, cacheWriteCost: 0.5, cacheReadCost: 0.1)
        let b = CostBreakdown(inputCost: 3.0, outputCost: 4.0, cacheWriteCost: 1.5, cacheReadCost: 0.2)
        let sum = a + b
        XCTAssertEqual(sum.inputCost, 4.0, accuracy: 0.001)
        XCTAssertEqual(sum.outputCost, 6.0, accuracy: 0.001)
        XCTAssertEqual(sum.totalCost, 12.3, accuracy: 0.001)
    }
}
