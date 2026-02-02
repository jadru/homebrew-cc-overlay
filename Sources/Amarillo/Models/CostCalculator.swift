import Foundation

struct ModelPricing: Sendable {
    let inputPerMTok: Double
    let outputPerMTok: Double
    let cacheWritePerMTok: Double
    let cacheReadPerMTok: Double
}

struct CostBreakdown: Sendable, Equatable {
    let inputCost: Double
    let outputCost: Double
    let cacheWriteCost: Double
    let cacheReadCost: Double

    var totalCost: Double {
        inputCost + outputCost + cacheWriteCost + cacheReadCost
    }

    static let zero = CostBreakdown(inputCost: 0, outputCost: 0, cacheWriteCost: 0, cacheReadCost: 0)

    static func + (lhs: CostBreakdown, rhs: CostBreakdown) -> CostBreakdown {
        CostBreakdown(
            inputCost: lhs.inputCost + rhs.inputCost,
            outputCost: lhs.outputCost + rhs.outputCost,
            cacheWriteCost: lhs.cacheWriteCost + rhs.cacheWriteCost,
            cacheReadCost: lhs.cacheReadCost + rhs.cacheReadCost
        )
    }
}

enum CostCalculator {
    private static let pricingTable: [(prefix: String, pricing: ModelPricing)] = [
        ("claude-opus-4", ModelPricing(inputPerMTok: 15, outputPerMTok: 75, cacheWritePerMTok: 18.75, cacheReadPerMTok: 1.50)),
        ("claude-sonnet-4", ModelPricing(inputPerMTok: 3, outputPerMTok: 15, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30)),
        ("claude-3-5-haiku", ModelPricing(inputPerMTok: 0.80, outputPerMTok: 4, cacheWritePerMTok: 1.0, cacheReadPerMTok: 0.08)),
    ]

    private static let defaultPricing = ModelPricing(inputPerMTok: 3, outputPerMTok: 15, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30)

    static func pricing(for model: String) -> ModelPricing {
        for entry in pricingTable {
            if model.hasPrefix(entry.prefix) { return entry.pricing }
        }
        return defaultPricing
    }

    static func cost(for entry: ParsedUsageEntry) -> CostBreakdown {
        let p = pricing(for: entry.model)
        return CostBreakdown(
            inputCost: Double(entry.inputTokens) / 1_000_000 * p.inputPerMTok,
            outputCost: Double(entry.outputTokens) / 1_000_000 * p.outputPerMTok,
            cacheWriteCost: Double(entry.cacheCreationTokens) / 1_000_000 * p.cacheWritePerMTok,
            cacheReadCost: Double(entry.cacheReadTokens) / 1_000_000 * p.cacheReadPerMTok
        )
    }

    static func cost(for entries: [ParsedUsageEntry]) -> CostBreakdown {
        entries.reduce(.zero) { $0 + cost(for: $1) }
    }

    static func cost(for session: SessionUsage) -> CostBreakdown {
        let p = pricing(for: session.model)
        let u = session.tokenUsage
        return CostBreakdown(
            inputCost: Double(u.inputTokens) / 1_000_000 * p.inputPerMTok,
            outputCost: Double(u.outputTokens) / 1_000_000 * p.outputPerMTok,
            cacheWriteCost: Double(u.cacheCreationInputTokens) / 1_000_000 * p.cacheWritePerMTok,
            cacheReadCost: Double(u.cacheReadInputTokens) / 1_000_000 * p.cacheReadPerMTok
        )
    }
}
