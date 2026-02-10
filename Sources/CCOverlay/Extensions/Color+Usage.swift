import SwiftUI

extension Color {
    /// Returns a tint color based on the remaining usage percentage.
    /// - Parameter remainingPercentage: The remaining percentage (0-100)
    /// - Returns: Red (≤10%), Orange (≤30%), Yellow (≤60%), Green (>60%)
    static func usageTint(for remainingPercentage: Double) -> Color {
        if remainingPercentage <= 10 { return .red }
        if remainingPercentage <= 30 { return .orange }
        if remainingPercentage <= 60 { return .yellow }
        return .green
    }

    /// Returns a tint color for rate limit utilization percentage.
    /// - Parameter utilization: The utilization percentage (0-100)
    /// - Returns: Red (≥90%), Orange (≥70%), Secondary (otherwise)
    static func rateLimitTint(for utilization: Double) -> Color {
        if utilization >= 90 { return .red }
        if utilization >= 70 { return .orange }
        return .secondary
    }

    /// Returns a 6-stage tint color for chart utilization display.
    /// - Parameter utilization: The utilization percentage (0-100)
    static func chartTint(for utilization: Double) -> Color {
        if utilization >= 90 { return .red }
        if utilization >= 75 { return Color(red: 1.0, green: 0.3, blue: 0.0) }
        if utilization >= 55 { return .orange }
        if utilization >= 35 { return .yellow }
        if utilization >= 15 { return .mint }
        return .green
    }
}
