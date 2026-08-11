import Foundation

/// Maps live usage headroom to Patch's immediate working mood. Long-lived
/// workshop gear is intentionally not part of this calculation.
struct PatchPresentation: Equatable, Sendable {
    enum Mood: String, Equatable, Sendable {
        case offline
        case resting
        case watchful
        case focused
        case thriving
    }

    let mood: Mood
    let headroomPercentage: Double?
    let pace: RateWindowPace.Status
    let resetAt: Date?

    var title: String {
        switch mood {
        case .offline: "Patch is offline"
        case .resting: "Patch is resting"
        case .watchful: "Patch is on watch"
        case .focused: "Patch is focused"
        case .thriving: "Patch is ready"
        }
    }

    var detail: String {
        switch mood {
        case .offline:
            "Patch wakes when a provider reports live usage."
        case .resting:
            "Headroom is low. Protect the next reset before starting more work."
        case .watchful:
            "Some headroom remains—reserve the next run for what matters."
        case .focused where pace == .burningFast:
            "You have room, but usage is burning faster than the reset pace."
        case .focused:
            "Your current runway is steady."
        case .thriving:
            "Plenty of headroom and a sustainable pace."
        }
    }

    var symbolName: String {
        switch mood {
        case .offline: "moon.stars"
        case .resting: "bed.double.fill"
        case .watchful: "eye.fill"
        case .focused: "pawprint.fill"
        case .thriving: "sparkles"
        }
    }

    var companionOpacity: Double {
        switch mood {
        case .offline: 0.42
        case .resting: 0.56
        case .watchful: 0.72
        case .focused: 0.88
        case .thriving: 1
        }
    }

    var companionSaturation: Double {
        switch mood {
        case .offline: 0.2
        case .resting: 0.46
        case .watchful: 0.72
        case .focused: 0.9
        case .thriving: 1
        }
    }

    var companionScale: Double {
        switch mood {
        case .offline: 0.82
        case .resting: 0.86
        case .watchful: 0.91
        case .focused: 0.96
        case .thriving: 1
        }
    }

    static func assess(
        providerData: [ProviderUsageData],
        now: Date = Date(),
        staleAfter: TimeInterval = 180
    ) -> PatchPresentation {
        let usableData = providerData.filter(\.isAvailable)
        guard let mostConstrained = usableData.min(by: {
            UsageDecisionEngine.headroom(for: $0) < UsageDecisionEngine.headroom(for: $1)
        }) else {
            return PatchPresentation(mood: .offline, headroomPercentage: nil, pace: .unavailable, resetAt: nil)
        }

        let isStale = mostConstrained.lastRefresh.map {
            now.timeIntervalSince($0) > staleAfter
        } ?? false
        guard mostConstrained.error == nil, !isStale else {
            return PatchPresentation(
                mood: .offline,
                headroomPercentage: nil,
                pace: .unavailable,
                resetAt: nextReset(for: mostConstrained, after: now)
            )
        }

        let headroom = UsageDecisionEngine.headroom(for: mostConstrained)
        let pace = mostUrgentPace(for: mostConstrained, now: now)
        let mood: Mood

        if headroom <= 10 {
            mood = .resting
        } else if headroom <= 35 {
            mood = .watchful
        } else if headroom >= 65, pace != .burningFast {
            mood = .thriving
        } else {
            mood = .focused
        }

        return PatchPresentation(
            mood: mood,
            headroomPercentage: headroom,
            pace: pace,
            resetAt: nextReset(for: mostConstrained, after: now)
        )
    }

    private static func nextReset(for data: ProviderUsageData, after now: Date) -> Date? {
        ([data.resetsAt] + data.rateLimitBuckets.map(\.resetsAt))
            .compactMap { $0 }
            .filter { $0 > now }
            .min()
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

    private static func canonicalWindowLabel(_ label: String) -> String? {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "5h": return "5h"
        case "1w", "7d": return "7d"
        default: return nil
        }
    }
}
