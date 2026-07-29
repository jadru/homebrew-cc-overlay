import Foundation

enum PreferredTerminal: String, CaseIterable, Codable, Identifiable, Sendable {
    case terminal
    case iTerm

    var id: String { rawValue }

    var label: String {
        switch self {
        case .terminal: return "Terminal"
        case .iTerm: return "iTerm2"
        }
    }
}

enum ProviderPriority: String, CaseIterable, Codable, Identifiable, Sendable {
    case codexFirst
    case mostHeadroom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .codexFirst: return "Codex first"
        case .mostHeadroom: return "Most headroom"
        }
    }

    var detail: String {
        switch self {
        case .codexFirst:
            return "Prefer Codex when it can safely fit the task, then fall back to Claude Code."
        case .mostHeadroom:
            return "Choose whichever connected provider currently has the most usable headroom."
        }
    }

}

enum FullResetPolicy: String, CaseIterable, Codable, Identifiable, Sendable {
    case balanced
    case conserveLast
    case preferReset

    var id: String { rawValue }

    var label: String {
        switch self {
        case .balanced: return "Balanced"
        case .conserveLast: return "Save last reset"
        case .preferReset: return "Prefer reset"
        }
    }

    var detail: String {
        switch self {
        case .balanced: return "Use a Full Reset when Codex needs it and switching is not safer."
        case .conserveLast: return "Keep the final reset unless it is close to expiring."
        case .preferReset: return "Prefer an applicable Full Reset over switching providers."
        }
    }
}

struct ProviderActivationStatus: Equatable, Sendable {
    enum Kind: String, Sendable {
        case ready
        case checking
        case cliMissing
        case signInRequired
        case stale
        case schemaChanged
        case failed
    }

    let provider: CLIProvider
    let kind: Kind
    let title: String
    let detail: String
    let recoveryCommand: String?

    var canRecover: Bool { recoveryCommand != nil }
}

struct ProviderHealthSnapshot: Equatable, Sendable {
    let provider: CLIProvider
    let activation: ProviderActivationStatus
    let lastSuccess: Date?
    let responseTime: TimeInterval?
    let consecutiveFailures: Int

    var isHealthy: Bool {
        activation.kind == .ready && consecutiveFailures == 0
    }
}

enum RunOutcome: String, CaseIterable, Codable, Identifiable, Sendable {
    case completed
    case hitLimit
    case switchedProvider
    case usedReset
    case cancelled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .completed: return "Finished"
        case .hitLimit: return "Hit limit"
        case .switchedProvider: return "Switched"
        case .usedReset: return "Used reset"
        case .cancelled: return "Cancelled"
        }
    }
}

struct PendingRun: Codable, Equatable, Sendable {
    let id: UUID
    let startedAt: Date
    let provider: CLIProvider
    let taskSize: PlannedTaskSize
    let startingHeadroom: Double
    let projectName: String?
}

struct UsageHistoryPoint: Equatable, Identifiable, Sendable {
    let timestamp: Date
    let remainingPercentage: Double

    var id: Date { timestamp }
}

struct ProviderHeadroomForecast: Equatable, Sendable {
    let exhaustionAt: Date?
    let consumptionPerHour: Double
    let sampleCount: Int
    let resetsBeforeExhaustion: Bool

    var label: String {
        if resetsBeforeExhaustion { return "Reset arrives first" }
        guard let exhaustionAt else { return "Learning active pace" }
        let remaining = exhaustionAt.timeIntervalSinceNow
        if remaining <= 0 { return "At limit" }
        return "\(DurationFormatting.compactReset(remaining)) to limit"
    }
}
