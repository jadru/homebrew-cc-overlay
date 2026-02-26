import Foundation

// MARK: - CLI Provider

enum CLIProvider: String, CaseIterable, Identifiable, Sendable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case gemini = "Gemini"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .claudeCode: return "brain"
        case .codex: return "terminal.fill"
        case .gemini: return "sparkles"
        }
    }

    /// Short 2-letter label for compact pill overlay.
    var shortLabel: String {
        switch self {
        case .claudeCode: return "CC"
        case .codex: return "CX"
        case .gemini: return "GM"
        }
    }
}

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
    case enterprise = "Enterprise"
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
        case .enterprise: return 100_000_000
        case .custom: return 5_000_000
        }
    }

    /// Map an API subscription type string to a display name.
    static func displayName(for subscriptionType: String) -> String {
        switch subscriptionType {
        case "max_5": return "Max ($100/mo)"
        case "max_20": return "Max ($200/mo)"
        case "pro": return "Pro ($20/mo)"
        case let s where s.hasPrefix("enterprise"): return "Enterprise"
        default: return subscriptionType
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

// MARK: - Menu Bar Indicator Style

enum MenuBarIndicatorStyle: String, CaseIterable, Identifiable, Sendable {
    case pieChart = "Pie Chart"
    case barChart = "Bar Chart"
    case percentage = "Percentage"

    var id: String { rawValue }
}


// MARK: - App Constants

enum AppConstants {
    static let version = "0.7.0"
    static let githubRepo = "jadru/cc-overlay"
    static let updateCheckInterval: TimeInterval = 86400 // 24h

    static let claudeProjectsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/projects"
    }()

    static let codexConfigPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.codex"
    }()

    static let geminiConfigPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.gemini"
    }()

    static let defaultRefreshInterval: TimeInterval = 60
    static let fiveHourWindowSeconds: TimeInterval = 5 * 60 * 60
    static let sessionScanInterval: TimeInterval = 5

    // Thresholds
    static let defaultWarningThresholdPct: Double = 70
    static let defaultCriticalThresholdPct: Double = 90
    static let warningThresholdPct: Double = defaultWarningThresholdPct

    // Activity detection
    static let activityWindowSeconds: TimeInterval = 5 * 60

    // Time
    static let secondsPerDay: TimeInterval = 86400

    // Network
    static let apiTimeoutInterval: TimeInterval = 10
    static let oauthTimeoutInterval: TimeInterval = 15
}
