import Foundation

/// The Mac-side readiness signal that is combined with provider headroom before
/// CC-Overlay recommends starting an intensive AI coding run.
struct SystemReadiness: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case unavailable
        case ready
        case caution
        case blocked
    }

    let status: Status
    let reasons: [String]

    static let unavailable = SystemReadiness(status: .unavailable, reasons: ["System status is unavailable."])
    static let ready = SystemReadiness(status: .ready, reasons: [])
}

/// The final, user-facing next action after combining provider capacity with the
/// local Mac's ability to sustain the work.
struct CapacityDecision: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case run
        case runWithCaution
        case waitForMac
        case switchProvider
        case useReset
        case waitForHeadroom
        case refresh
        case setup
    }

    let kind: Kind
    let title: String
    let detail: String
    let recommendedProvider: CLIProvider?
    let nextSafeAt: Date?
    let confidence: UsageDecision.Confidence
    let dataQuality: UsageDecision.DataQuality
    let reasons: [String]
    let systemReadiness: SystemReadiness
}

enum CapacityDecisionEngine {
    private static let lowStorageThresholdBytes: Int64 = 10 * 1_024 * 1_024 * 1_024

    static func assessSystem(_ sample: SystemMetricsSample?) -> SystemReadiness {
        guard let sample else { return .unavailable }

        var blockingReasons: [String] = []
        if sample.memory.pressure == .critical {
            blockingReasons.append("Memory pressure is critical.")
        }
        if sample.thermalState == .critical {
            blockingReasons.append("Mac thermal state is critical.")
        }
        if !blockingReasons.isEmpty {
            return SystemReadiness(status: .blocked, reasons: blockingReasons)
        }

        var cautions: [String] = []
        if sample.memory.pressure == .warning {
            cautions.append("Memory pressure is elevated.")
        }
        if sample.thermalState == .serious {
            cautions.append("Mac thermal state is serious.")
        }
        if let cpu = sample.cpuUsagePercentage, cpu >= 90 {
            cautions.append("CPU use is at \(Int(cpu.rounded()))%.")
        }
        if let memory = sample.memory.usagePercentage, memory >= 90 {
            cautions.append("Memory use is at \(Int(memory.rounded()))%.")
        }
        if let availableBytes = sample.storage.availableBytes,
           availableBytes < lowStorageThresholdBytes {
            cautions.append("Free storage is below 10 GiB.")
        }
        return cautions.isEmpty
            ? .ready
            : SystemReadiness(status: .caution, reasons: cautions)
    }

    static func decide(
        providerDecision: UsageDecision,
        sample: SystemMetricsSample?,
        now: Date = Date()
    ) -> CapacityDecision {
        let readiness = assessSystem(sample)
        if readiness.status == .blocked {
            return CapacityDecision(
                kind: .waitForMac,
                title: "Wait for Mac",
                detail: "Let the Mac recover before starting another intensive run.",
                recommendedProvider: providerDecision.recommendedProvider,
                nextSafeAt: nil,
                confidence: providerDecision.confidence,
                dataQuality: providerDecision.dataQuality,
                reasons: readiness.reasons + providerDecision.reasons,
                systemReadiness: readiness
            )
        }

        switch providerDecision.kind {
        case .setup:
            return providerCapacityDecision(
                kind: .setup,
                providerDecision: providerDecision,
                readiness: readiness,
                nextSafeAt: nil
            )
        case .refresh:
            return providerCapacityDecision(
                kind: .refresh,
                providerDecision: providerDecision,
                readiness: readiness,
                nextSafeAt: nil
            )
        case .wait:
            return providerCapacityDecision(
                kind: .waitForHeadroom,
                providerDecision: providerDecision,
                readiness: readiness,
                nextSafeAt: providerDecision.resetAt
            )
        case .switchProvider:
            return providerCapacityDecision(
                kind: .switchProvider,
                providerDecision: providerDecision,
                readiness: readiness,
                nextSafeAt: now
            )
        case .useReset:
            return providerCapacityDecision(
                kind: .useReset,
                providerDecision: providerDecision,
                readiness: readiness,
                nextSafeAt: now
            )
        case .run:
            if readiness.status == .caution {
                return CapacityDecision(
                    kind: .runWithCaution,
                    title: "Run with caution",
                    detail: providerDecision.detail,
                    recommendedProvider: providerDecision.recommendedProvider,
                    nextSafeAt: now,
                    confidence: providerDecision.confidence,
                    dataQuality: providerDecision.dataQuality,
                    reasons: readiness.reasons + providerDecision.reasons,
                    systemReadiness: readiness
                )
            }
            return providerCapacityDecision(
                kind: .run,
                providerDecision: providerDecision,
                readiness: readiness,
                nextSafeAt: now
            )
        }
    }

    private static func providerCapacityDecision(
        kind: CapacityDecision.Kind,
        providerDecision: UsageDecision,
        readiness: SystemReadiness,
        nextSafeAt: Date?
    ) -> CapacityDecision {
        let cautionReasons = readiness.status == .caution ? readiness.reasons : []
        return CapacityDecision(
            kind: kind,
            title: providerDecision.title,
            detail: providerDecision.detail,
            recommendedProvider: providerDecision.recommendedProvider,
            nextSafeAt: nextSafeAt,
            confidence: providerDecision.confidence,
            dataQuality: providerDecision.dataQuality,
            reasons: cautionReasons + providerDecision.reasons,
            systemReadiness: readiness
        )
    }
}
