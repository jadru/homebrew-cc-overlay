import Foundation

enum PlannedTaskSize: String, CaseIterable, Codable, Identifiable, Sendable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }
}

struct TaskFitEvidence: Equatable, Sendable {
    /// Explicit, user-recorded outcomes are required before a task-fit estimate is shown.
    /// Passive usage deltas remain useful for pace forecasts, but cannot establish causality.
    static let minimumLearningSamples = 5
    static let minimumHighConfidenceSamples = 12

    let requiredHeadroom: Double
    let sampleCount: Int
}

struct TaskFitAssessment: Equatable, Sendable {
    enum Outcome: String, Codable, Equatable, Sendable {
        case likely
        case risky
        case unlikely
        case learning
    }

    let taskSize: PlannedTaskSize
    let outcome: Outcome
    let requiredHeadroom: Double?
    let sampleCount: Int

    var label: String {
        switch outcome {
        case .likely: return "Likely fits"
        case .risky: return "Risky"
        case .unlikely: return "Unlikely to fit"
        case .learning: return "Learning your usage"
        }
    }
}

/// A concise, actionable recommendation derived from all usable provider windows.
struct UsageDecision: Equatable, Sendable {
    enum Kind: String, Equatable, Hashable, Sendable {
        case run
        case switchProvider
        case useReset
        case wait
        case refresh
        case setup
    }

    enum Confidence: String, Codable, Equatable, Sendable {
        case high
        case medium
        case low

        var label: String { rawValue.capitalized }
    }

    enum DataQuality: String, Codable, Equatable, Sendable {
        case live
        case estimated
        case mixed
        case stale

        var label: String { rawValue.capitalized }
    }

    let kind: Kind
    let title: String
    let detail: String
    let recommendedProvider: CLIProvider?
    let resetAt: Date?
    let confidence: Confidence
    let dataQuality: DataQuality
    let taskFit: TaskFitAssessment?
    let recommendedHeadroom: Double?
    let reasons: [String]

    init(
        kind: Kind,
        title: String,
        detail: String,
        recommendedProvider: CLIProvider?,
        resetAt: Date?,
        confidence: Confidence = .medium,
        dataQuality: DataQuality = .live,
        taskFit: TaskFitAssessment? = nil,
        recommendedHeadroom: Double? = nil,
        reasons: [String] = []
    ) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.recommendedProvider = recommendedProvider
        self.resetAt = resetAt
        self.confidence = confidence
        self.dataQuality = dataQuality
        self.taskFit = taskFit
        self.recommendedHeadroom = recommendedHeadroom
        self.reasons = reasons
    }
}

enum UsageDecisionEngine {
    static func recommend(
        from providerData: [ProviderUsageData],
        currentProvider: CLIProvider? = nil,
        plannedTaskSize: PlannedTaskSize = .medium,
        fitEvidence: [CLIProvider: TaskFitEvidence] = [:],
        providerPriority: ProviderPriority = .codexFirst,
        fullResetPolicy: FullResetPolicy = .balanced,
        staleAfter: TimeInterval = 180,
        now: Date = Date()
    ) -> UsageDecision {
        let available = providerData.filter(\.isAvailable)
        guard !available.isEmpty else {
            return UsageDecision(
                kind: .setup,
                title: "Connect a provider",
                detail: "Sign in to Claude Code or Codex to get a live recommendation.",
                recommendedProvider: nil,
                resetAt: nil,
                confidence: .low,
                dataQuality: .stale,
                reasons: ["No connected provider returned usable usage data."]
            )
        }

        let fresh = available.filter { data in
            guard data.error == nil, let lastRefresh = data.lastRefresh else { return false }
            return now.timeIntervalSince(lastRefresh) <= staleAfter
        }

        guard !fresh.isEmpty else {
            return UsageDecision(
                kind: .refresh,
                title: "Refresh usage first",
                detail: "The connected provider data is stale or failed to refresh.",
                recommendedProvider: currentProvider,
                resetAt: nil,
                confidence: .low,
                dataQuality: .stale,
                reasons: ["Every connected snapshot is stale or contains a refresh error."]
            )
        }

        let ranked = fresh.sorted { headroom(for: $0) > headroom(for: $1) }
        let best = prioritizedProvider(
            in: fresh,
            fallback: ranked[0],
            priority: providerPriority,
            plannedTaskSize: plannedTaskSize,
            fitEvidence: fitEvidence
        )
        let bestHeadroom = headroom(for: best)
        let bestPace = mostUrgentPace(for: best, now: now)
        let taskFit = taskFitAssessment(
            evidence: fitEvidence[best.provider],
            taskSize: plannedTaskSize,
            availableHeadroom: bestHeadroom
        )
        let quality = dataQuality(fresh: fresh, availableCount: available.count)
        let baseConfidence = confidence(quality: quality, taskFit: taskFit)
        let applicableResetProvider = fresh.first {
            $0.creditsInfo?.hasUsableResetCredit(at: now) == true
        }

        func reasons(
            for data: ProviderUsageData,
            headroom: Double,
            fit: TaskFitAssessment
        ) -> [String] {
            var values = [
                "\(data.provider.rawValue) has \(Int(headroom.rounded()))% active-window headroom.",
                "\(fit.taskSize.label) task fit: \(fit.label).",
                "Task-fit evidence: \(fit.sampleCount) recorded outcome\(fit.sampleCount == 1 ? "" : "s").",
                "Data quality: \(quality.label).",
            ]
            if let alternative = ranked.first(where: { $0.provider != data.provider }) {
                values.append(
                    "\(alternative.provider.rawValue) has \(Int(Self.headroom(for: alternative).rounded()))% headroom."
                )
            }
            values.append("Provider priority: \(providerPriority.label).")
            return values
        }

        func fullResetDecision(for data: ProviderUsageData) -> UsageDecision {
            let count = data.creditsInfo?.resetCreditsApplicable ?? 0
            let expiration = data.creditsInfo?.nextResetCreditExpiration(after: now)
            let expirationDetail = expiration.map {
                " It expires in \(DurationFormatting.compactReset($0.timeIntervalSince(now)))."
            } ?? ""
            let resetTaskFit = taskFitAssessment(
                evidence: fitEvidence[data.provider],
                taskSize: plannedTaskSize,
                availableHeadroom: 100
            )
            return UsageDecision(
                kind: .useReset,
                title: "Use a Codex full reset",
                detail: "\(count) banked reset\(count == 1 ? " is" : "s are") ready to restore the Codex rate limit.\(expirationDetail)",
                recommendedProvider: data.provider,
                resetAt: nil,
                confidence: confidence(quality: quality, taskFit: resetTaskFit),
                dataQuality: quality,
                taskFit: resetTaskFit,
                recommendedHeadroom: 100,
                reasons: [
                    "Codex reports \(count) Full Reset\(count == 1 ? "" : "s") ready now.",
                    "A reset restores the active rate-limit window before this run.",
                    "Reset policy: \(fullResetPolicy.label).",
                ] + (expiration.map {
                    ["The next Full Reset expires in \(DurationFormatting.compactReset($0.timeIntervalSince(now)))."]
                } ?? [])
            )
        }

        if let resetProvider = applicableResetProvider,
           resetProvider.creditsInfo?.resetCreditExpiresSoon(at: now) == true,
           headroom(for: resetProvider) <= 10 {
            return fullResetDecision(for: resetProvider)
        }

        if fullResetPolicy == .preferReset,
           let resetProvider = applicableResetProvider,
           headroom(for: resetProvider) <= 10 {
            return fullResetDecision(for: resetProvider)
        }

        if ranked.count > 1,
           let currentProvider,
           let currentData = fresh.first(where: { $0.provider == currentProvider }),
           currentProvider != best.provider,
           headroom(for: currentData) <= 25,
           bestHeadroom - headroom(for: currentData) >= 20
        {
            let currentHeadroom = headroom(for: currentData)
            return UsageDecision(
                kind: .switchProvider,
                title: "Switch to \(best.provider.rawValue)",
                detail: "\(Int(bestHeadroom.rounded()))% headroom there versus \(Int(currentHeadroom.rounded()))% on \(currentProvider.rawValue).",
                recommendedProvider: best.provider,
                resetAt: best.resetsAt,
                confidence: baseConfidence,
                dataQuality: quality,
                taskFit: taskFit,
                recommendedHeadroom: bestHeadroom,
                reasons: reasons(for: best, headroom: bestHeadroom, fit: taskFit)
            )
        }

        if taskFit.outcome == .unlikely || bestHeadroom <= 10 || (bestHeadroom <= 20 && bestPace == .burningFast) {
            if let resetProvider = applicableResetProvider {
                let available = resetProvider.creditsInfo?.resetCreditsAvailable ?? 0
                let expiresSoon = resetProvider.creditsInfo?.resetCreditExpiresSoon(at: now) == true
                if fullResetPolicy != .conserveLast || available > 1 || expiresSoon {
                    return fullResetDecision(for: resetProvider)
                }
            }

            let reset = earliestFutureReset(in: fresh, now: now)
            let detail = taskFit.outcome == .unlikely
                ? "Your recent \(plannedTaskSize.label.lowercased()) activity needs more headroom than is currently available."
                : reset == nil
                    ? "Every connected provider is close to its active limit."
                    : "The safest option is to resume after the next reset."
            return UsageDecision(
                kind: .wait,
                title: "Wait for headroom",
                detail: detail,
                recommendedProvider: best.provider,
                resetAt: reset,
                confidence: baseConfidence,
                dataQuality: quality,
                taskFit: taskFit,
                recommendedHeadroom: bestHeadroom,
                reasons: reasons(for: best, headroom: bestHeadroom, fit: taskFit)
                    + (fullResetPolicy == .conserveLast && applicableResetProvider != nil
                        ? ["The final Full Reset is being preserved because it is not close to expiring."]
                        : [])
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
            resetAt: best.resetsAt,
            confidence: taskFit.outcome == .risky ? .low : baseConfidence,
            dataQuality: quality,
            taskFit: taskFit,
            recommendedHeadroom: bestHeadroom,
            reasons: reasons(for: best, headroom: bestHeadroom, fit: taskFit)
        )
    }

    static func headroom(for data: ProviderUsageData) -> Double {
        let activeWindowHeadroom = data.rateLimitBuckets
            .filter { canonicalWindowLabel($0.label) != nil }
            .map { max(0, min(100, 100 - $0.utilization)) }

        return activeWindowHeadroom.min() ?? max(0, min(100, data.remainingPercentage))
    }

    private static func prioritizedProvider(
        in fresh: [ProviderUsageData],
        fallback: ProviderUsageData,
        priority: ProviderPriority,
        plannedTaskSize: PlannedTaskSize,
        fitEvidence: [CLIProvider: TaskFitEvidence]
    ) -> ProviderUsageData {
        guard priority == .codexFirst,
              let codex = fresh.first(where: { $0.provider == .codex })
        else {
            return fallback
        }
        if fallback.provider == .codex || fresh.count == 1 {
            return codex
        }

        let codexHeadroom = headroom(for: codex)
        let fit = taskFitAssessment(
            evidence: fitEvidence[.codex],
            taskSize: plannedTaskSize,
            availableHeadroom: codexHeadroom
        )
        let safelyFits = codexHeadroom >= 25
            && (fit.outcome == .likely || fit.outcome == .learning)
        return safelyFits ? codex : fallback
    }

    private static func taskFitAssessment(
        evidence: TaskFitEvidence?,
        taskSize: PlannedTaskSize,
        availableHeadroom: Double
    ) -> TaskFitAssessment {
        guard let evidence, evidence.sampleCount >= TaskFitEvidence.minimumLearningSamples else {
            return TaskFitAssessment(
                taskSize: taskSize,
                outcome: .learning,
                requiredHeadroom: nil,
                sampleCount: evidence?.sampleCount ?? 0
            )
        }

        let outcome: TaskFitAssessment.Outcome
        if availableHeadroom >= evidence.requiredHeadroom * 1.35 {
            outcome = .likely
        } else if availableHeadroom >= evidence.requiredHeadroom {
            outcome = .risky
        } else {
            outcome = .unlikely
        }

        return TaskFitAssessment(
            taskSize: taskSize,
            outcome: outcome,
            requiredHeadroom: evidence.requiredHeadroom,
            sampleCount: evidence.sampleCount
        )
    }

    private static func dataQuality(
        fresh: [ProviderUsageData],
        availableCount: Int
    ) -> UsageDecision.DataQuality {
        if fresh.count < availableCount { return .mixed }
        if fresh.allSatisfy(\.isEstimated) { return .estimated }
        if fresh.contains(where: \.isEstimated) { return .mixed }
        return .live
    }

    private static func confidence(
        quality: UsageDecision.DataQuality,
        taskFit: TaskFitAssessment
    ) -> UsageDecision.Confidence {
        if quality == .stale || quality == .estimated || taskFit.outcome == .risky {
            return .low
        }
        if quality == .mixed
            || taskFit.outcome == .learning
            || taskFit.sampleCount < TaskFitEvidence.minimumHighConfidenceSamples
        {
            return .medium
        }
        return .high
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

/// Keeps non-urgent recommendations from flipping after a single refresh.
final class UsageDecisionStabilizer {
    private struct Signature: Equatable {
        let kind: UsageDecision.Kind
        let provider: CLIProvider?
    }

    private var stableDecision: UsageDecision?
    private var pendingSignature: Signature?
    private var pendingCount = 0
    private var lastSnapshotVersion: Date?

    func reset() {
        stableDecision = nil
        pendingSignature = nil
        pendingCount = 0
        lastSnapshotVersion = nil
    }

    func resolve(candidate: UsageDecision, snapshotVersion: Date?) -> UsageDecision {
        let candidateSignature = Signature(
            kind: candidate.kind,
            provider: candidate.recommendedProvider
        )

        guard let stableDecision else {
            self.stableDecision = candidate
            return candidate
        }

        let stableSignature = Signature(
            kind: stableDecision.kind,
            provider: stableDecision.recommendedProvider
        )

        if candidateSignature == stableSignature {
            self.stableDecision = candidate
            pendingSignature = nil
            pendingCount = 0
            return candidate
        }

        if candidate.kind == .useReset || candidate.kind == .wait || candidate.kind == .refresh || candidate.kind == .setup {
            self.stableDecision = candidate
            pendingSignature = nil
            pendingCount = 0
            lastSnapshotVersion = snapshotVersion
            return candidate
        }

        if stableDecision.kind == .useReset {
            self.stableDecision = candidate
            pendingSignature = nil
            pendingCount = 0
            lastSnapshotVersion = snapshotVersion
            return candidate
        }

        guard snapshotVersion != lastSnapshotVersion else {
            return stableDecision
        }
        lastSnapshotVersion = snapshotVersion

        if pendingSignature == candidateSignature {
            pendingCount += 1
        } else {
            pendingSignature = candidateSignature
            pendingCount = 1
        }

        guard pendingCount >= 2 else { return stableDecision }
        self.stableDecision = candidate
        pendingSignature = nil
        pendingCount = 0
        return candidate
    }
}
