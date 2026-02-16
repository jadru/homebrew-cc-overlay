import Foundation

enum GeminiCostCalculator {
    private static let pricingTable: [(prefix: String, pricing: ModelPricing)] = [
        // Gemini 3 (Preview)
        ("gemini-3-pro", ModelPricing(inputPerMTok: 2.00, outputPerMTok: 12.00, cacheWritePerMTok: 0, cacheReadPerMTok: 0)),
        ("gemini-3-flash", ModelPricing(inputPerMTok: 0.50, outputPerMTok: 3.00, cacheWritePerMTok: 0, cacheReadPerMTok: 0)),

        // Gemini 2.5
        ("gemini-2.5-pro", ModelPricing(inputPerMTok: 1.25, outputPerMTok: 10.00, cacheWritePerMTok: 0, cacheReadPerMTok: 0)),
        ("gemini-2.5-flash", ModelPricing(inputPerMTok: 0.30, outputPerMTok: 2.50, cacheWritePerMTok: 0, cacheReadPerMTok: 0)),

        // Gemini 2.0
        ("gemini-2.0-flash", ModelPricing(inputPerMTok: 0.10, outputPerMTok: 0.40, cacheWritePerMTok: 0, cacheReadPerMTok: 0)),

        // Gemini 1.5 (legacy)
        ("gemini-1.5-pro", ModelPricing(inputPerMTok: 1.25, outputPerMTok: 5.00, cacheWritePerMTok: 0, cacheReadPerMTok: 0.3125)),
        ("gemini-1.5-flash", ModelPricing(inputPerMTok: 0.075, outputPerMTok: 0.30, cacheWritePerMTok: 0, cacheReadPerMTok: 0.01875)),
    ]

    // Default: Gemini 2.5 Pro (CLI default model)
    private static let defaultPricing = ModelPricing(
        inputPerMTok: 1.25, outputPerMTok: 10.00,
        cacheWritePerMTok: 0, cacheReadPerMTok: 0
    )

    static func pricing(for model: String) -> ModelPricing {
        let normalized = model.lowercased()
        for entry in pricingTable {
            if normalized.hasPrefix(entry.prefix) { return entry.pricing }
        }
        return defaultPricing
    }

    static func calculateCost(inputTokens: Int, outputTokens: Int, model: String) -> CostBreakdown {
        let p = pricing(for: model)
        return CostBreakdown(
            inputCost: Double(inputTokens) / 1_000_000 * p.inputPerMTok,
            outputCost: Double(outputTokens) / 1_000_000 * p.outputPerMTok,
            cacheWriteCost: 0,
            cacheReadCost: 0
        )
    }
}
