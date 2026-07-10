import Foundation

/// Compares current rate-limit usage with a steady burn across its reset window.
struct RateWindowPace: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case burningFast
        case onPace
        case plentyLeft
        case unavailable
    }

    let utilization: Double
    let expectedUtilization: Double
    let status: Status

    static func assess(
        label: String,
        utilization: Double,
        resetsAt: Date?,
        now: Date = Date()
    ) -> RateWindowPace {
        let used = min(max(utilization, 0), 100)
        guard let resetsAt,
              resetsAt > now,
              let duration = windowDuration(for: label)
        else {
            return RateWindowPace(
                utilization: used,
                expectedUtilization: 0,
                status: .unavailable
            )
        }

        let remaining = min(max(resetsAt.timeIntervalSince(now), 0), duration)
        let expected = min(max((1 - remaining / duration) * 100, 0), 100)
        let difference = used - expected
        let status: Status

        if difference >= 12 {
            status = .burningFast
        } else if difference <= -12 {
            status = .plentyLeft
        } else {
            status = .onPace
        }

        return RateWindowPace(
            utilization: used,
            expectedUtilization: expected,
            status: status
        )
    }

    private static func windowDuration(for label: String) -> TimeInterval? {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "5h": return AppConstants.fiveHourWindowSeconds
        case "1w", "7d": return 7 * AppConstants.secondsPerDay
        default: return nil
        }
    }
}
