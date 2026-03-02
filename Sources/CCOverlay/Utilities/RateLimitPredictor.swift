import Foundation

struct RateLimitPrediction: Sendable {
    let estimatedExhaustionDate: Date?
    let formattedTimeRemaining: String?
    let consumptionRatePerHour: Double
}

enum RateLimitPredictor {

    /// Predict when rate limit will be exhausted based on recent snapshots.
    ///
    /// - Parameters:
    ///   - currentUtilization: Current utilization percentage (0-100)
    ///   - recentSnapshots: Chronologically ordered snapshots
    ///   - resetsAt: When the rate limit window resets
    /// - Returns: Prediction with estimated time to exhaustion
    static func predict(
        currentUtilization: Double,
        recentSnapshots: [UsageSnapshot],
        resetsAt: Date?
    ) -> RateLimitPrediction {
        guard currentUtilization < 100 else {
            return RateLimitPrediction(
                estimatedExhaustionDate: nil,
                formattedTimeRemaining: nil,
                consumptionRatePerHour: 0
            )
        }

        // Need at least 2 data points to calculate a rate
        guard recentSnapshots.count >= 2 else {
            return RateLimitPrediction(
                estimatedExhaustionDate: nil,
                formattedTimeRemaining: nil,
                consumptionRatePerHour: 0
            )
        }

        // Calculate consumption rate from snapshots
        let first = recentSnapshots[0]
        let last = recentSnapshots[recentSnapshots.count - 1]
        let timeDelta = last.timestamp.timeIntervalSince(first.timestamp)

        guard timeDelta > 0 else {
            return RateLimitPrediction(
                estimatedExhaustionDate: nil,
                formattedTimeRemaining: nil,
                consumptionRatePerHour: 0
            )
        }

        // Use totalCost as proxy for utilization growth
        let costDelta = last.totalCost - first.totalCost
        guard costDelta > 0 else {
            return RateLimitPrediction(
                estimatedExhaustionDate: nil,
                formattedTimeRemaining: nil,
                consumptionRatePerHour: 0
            )
        }

        let hoursElapsed = timeDelta / 3600
        let ratePerHour = costDelta / hoursElapsed

        // Estimate remaining capacity using current utilization
        let remainingPct = 100.0 - currentUtilization
        // Assume linear relationship between cost and utilization
        let costPerPctPoint = costDelta / max(currentUtilization - (first.totalCost > 0 ? first.totalCost / last.totalCost * currentUtilization : 0), 1)
        let remainingCost = remainingPct * costPerPctPoint
        let hoursToExhaustion = remainingCost / ratePerHour

        let exhaustionDate = Date().addingTimeInterval(hoursToExhaustion * 3600)

        // If reset happens before exhaustion, note it
        if let resetsAt, resetsAt < exhaustionDate {
            return RateLimitPrediction(
                estimatedExhaustionDate: exhaustionDate,
                formattedTimeRemaining: "Resets before limit",
                consumptionRatePerHour: ratePerHour
            )
        }

        let formatted = formatTimeRemaining(hours: hoursToExhaustion)
        return RateLimitPrediction(
            estimatedExhaustionDate: exhaustionDate,
            formattedTimeRemaining: formatted,
            consumptionRatePerHour: ratePerHour
        )
    }

    private static func formatTimeRemaining(hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60

        if h > 0 {
            return "~\(h)h \(m)m to limit"
        } else if m > 0 {
            return "~\(m)m to limit"
        } else {
            return "At limit"
        }
    }
}
