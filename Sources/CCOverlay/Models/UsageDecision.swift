import Foundation

/// A concise, actionable recommendation derived from all usable provider windows.
struct UsageDecision: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case run
        case switchProvider
        case wait
        case setup
    }

    let kind: Kind
    let title: String
    let detail: String
    let recommendedProvider: CLIProvider?
    let resetAt: Date?
}

enum UsageDecisionEngine {
    static func recommend(
        from providerData: [ProviderUsageData],
        currentProvider: CLIProvider? = nil,
        now: Date = Date()
    ) -> UsageDecision {
        let available = providerData.filter(\.isAvailable)
        guard !available.isEmpty else {
            return UsageDecision(
                kind: .setup,
                title: "Connect a provider",
                detail: "Sign in to Claude Code or Codex to get a live recommendation.",
                recommendedProvider: nil,
                resetAt: nil
            )
        }

        let ranked = available.sorted { headroom(for: $0) > headroom(for: $1) }
        let best = ranked[0]
        let mostConstrained = ranked[ranked.count - 1]
        let bestHeadroom = headroom(for: best)
        let constrainedHeadroom = headroom(for: mostConstrained)
        let bestPace = mostUrgentPace(for: best, now: now)

        if ranked.count > 1,
           currentProvider == mostConstrained.provider,
           mostConstrained.provider != best.provider,
           constrainedHeadroom <= 25,
           bestHeadroom - constrainedHeadroom >= 20
        {
            return UsageDecision(
                kind: .switchProvider,
                title: "Switch to \(best.provider.rawValue)",
                detail: "\(Int(bestHeadroom.rounded()))% headroom there versus \(Int(constrainedHeadroom.rounded()))% on \(mostConstrained.provider.rawValue).",
                recommendedProvider: best.provider,
                resetAt: best.resetsAt
            )
        }

        if bestHeadroom <= 10 || (bestHeadroom <= 20 && bestPace == .burningFast) {
            let reset = earliestFutureReset(in: available, now: now)
            return UsageDecision(
                kind: .wait,
                title: "Wait for headroom",
                detail: reset == nil
                    ? "Every connected provider is close to its active limit."
                    : "The safest option is to resume after the next reset.",
                recommendedProvider: nil,
                resetAt: reset
            )
        }

        let paceDetail: String
        switch bestPace {
        case .burningFast:
            paceDetail = "You have room, but current burn is faster than the reset pace."
        case .plentyLeft:
            paceDetail = "Plenty left relative to the current reset pace."
        case .onPace:
            paceDetail = "Current usage is on pace for the active window."
        case .unavailable:
            paceDetail = "Best available headroom across connected providers."
        }

        return UsageDecision(
            kind: .run,
            title: "Run on \(best.provider.rawValue)",
            detail: "\(Int(bestHeadroom.rounded()))% headroom. \(paceDetail)",
            recommendedProvider: best.provider,
            resetAt: best.resetsAt
        )
    }

    static func headroom(for data: ProviderUsageData) -> Double {
        let activeWindowHeadroom = data.rateLimitBuckets
            .filter { canonicalWindowLabel($0.label) != nil }
            .map { max(0, min(100, 100 - $0.utilization)) }

        return activeWindowHeadroom.min() ?? max(0, min(100, data.remainingPercentage))
    }

    private static func mostUrgentPace(
        for data: ProviderUsageData,
        now: Date
    ) -> RateWindowPace.Status {
        let statuses = data.rateLimitBuckets.compactMap { bucket -> RateWindowPace.Status? in
            guard canonicalWindowLabel(bucket.label) != nil else { return nil }
            return RateWindowPace.assess(
                label: bucket.label,
                utilization: bucket.utilization,
                resetsAt: bucket.resetsAt,
                now: now
            ).status
        }

        if statuses.contains(.burningFast) { return .burningFast }
        if statuses.contains(.onPace) { return .onPace }
        if statuses.contains(.plentyLeft) { return .plentyLeft }
        return .unavailable
    }

    private static func earliestFutureReset(
        in data: [ProviderUsageData],
        now: Date
    ) -> Date? {
        data.flatMap { item in
            [item.resetsAt] + item.rateLimitBuckets.map(\.resetsAt)
        }
        .compactMap { $0 }
        .filter { $0 > now }
        .min()
    }

    private static func canonicalWindowLabel(_ label: String) -> String? {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "5h": return "5h"
        case "1w", "7d": return "7d"
        default: return nil
        }
    }
}
