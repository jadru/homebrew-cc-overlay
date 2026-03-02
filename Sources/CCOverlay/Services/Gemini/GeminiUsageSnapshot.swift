import Foundation

struct GeminiUsageSnapshot: Sendable {
    let tier: GeminiTier
    let rpmUtilization: Double
    let rpdUtilization: Double
    let estimatedInputTokens: Int
    let estimatedOutputTokens: Int
    let estimatedCostToday: Double
    let requestCount: Int
    let sessionCount: Int
    let accountEmail: String?
    let model: String?
    let fetchedAt: Date
}
