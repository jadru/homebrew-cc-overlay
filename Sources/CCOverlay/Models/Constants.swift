import Foundation

// MARK: - Billing Mode

enum BillingMode: String, CaseIterable, Identifiable, Sendable {
    case subscription = "Subscription (OAuth)"
    case apiKey = "API Key"

    var id: String { rawValue }
}

// MARK: - Plan Tiers (Subscription)

enum PlanTier: String, CaseIterable, Identifiable, Sendable {
    case pro = "Pro ($20/mo)"
    case max5 = "Max ($100/mo)"
    case max20 = "Max ($200/mo)"
    case custom = "Custom"

    var id: String { rawValue }

    /// Estimated 5-hour window limit in weighted cost units.
    /// Weighted cost = input*1.0 + output*5.0 + cache_create*1.25 + cache_read*0.1
    /// These are approximate; exact limits are not publicly documented.
    var weightedCostLimit: Double {
        switch self {
        case .pro: return 5_000_000
        case .max5: return 25_000_000
        case .max20: return 100_000_000
        case .custom: return 5_000_000
        }
    }
}

// MARK: - Token Cost Weights

/// Cost weights relative to base input token price.
/// Based on Anthropic API pricing ratios (consistent across models).
enum TokenCostWeight {
    static let input: Double = 1.0
    static let output: Double = 5.0
    static let cacheCreation: Double = 1.25
    static let cacheRead: Double = 0.1
}

// MARK: - App Constants

enum AppConstants {
    static let claudeProjectsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/projects"
    }()

    static let defaultRefreshInterval: TimeInterval = 60
    static let fiveHourWindowSeconds: TimeInterval = 5 * 60 * 60
    static let sessionScanInterval: TimeInterval = 5
}
