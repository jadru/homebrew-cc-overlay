import Foundation

enum OpenAICostCalculator {
    private static let pricingTable: [(prefix: String, pricing: ModelPricing)] = [
        // o4-mini (Codex default)
        ("o4-mini", ModelPricing(inputPerMTok: 1.10, outputPerMTok: 4.40, cacheWritePerMTok: 0, cacheReadPerMTok: 0.275)),
        // o3
        ("o3-mini", ModelPricing(inputPerMTok: 1.10, outputPerMTok: 4.40, cacheWritePerMTok: 0, cacheReadPerMTok: 0)),
        ("o3", ModelPricing(inputPerMTok: 2.0, outputPerMTok: 8.0, cacheWritePerMTok: 0, cacheReadPerMTok: 0.50)),
        // GPT-4.1 family
        ("gpt-4.1-nano", ModelPricing(inputPerMTok: 0.10, outputPerMTok: 0.40, cacheWritePerMTok: 0, cacheReadPerMTok: 0.025)),
        ("gpt-4.1-mini", ModelPricing(inputPerMTok: 0.40, outputPerMTok: 1.60, cacheWritePerMTok: 0, cacheReadPerMTok: 0.10)),
        ("gpt-4.1", ModelPricing(inputPerMTok: 2.0, outputPerMTok: 8.0, cacheWritePerMTok: 0, cacheReadPerMTok: 0.50)),
        // GPT-4o family
        ("gpt-4o-mini", ModelPricing(inputPerMTok: 0.15, outputPerMTok: 0.60, cacheWritePerMTok: 0, cacheReadPerMTok: 0.075)),
        ("gpt-4o", ModelPricing(inputPerMTok: 2.50, outputPerMTok: 10.0, cacheWritePerMTok: 0, cacheReadPerMTok: 1.25)),
    ]

    // Default: o4-mini pricing (Codex default model)
    private static let defaultPricing = ModelPricing(
        inputPerMTok: 1.10, outputPerMTok: 4.40,
        cacheWritePerMTok: 0, cacheReadPerMTok: 0.275
    )

    static func pricing(for model: String) -> ModelPricing {
        for entry in pricingTable {
            if model.hasPrefix(entry.prefix) { return entry.pricing }
        }
        return defaultPricing
    }
}
