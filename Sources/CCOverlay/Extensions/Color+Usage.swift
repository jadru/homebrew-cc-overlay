import SwiftUI

extension Color {
    /// Returns a tint color based on the remaining usage percentage.
    /// - Parameter remainingPercentage: The remaining percentage (0-100)
    static func usageTint(for remainingPercentage: Double) -> Color {
        if remainingPercentage <= 5 { return .red }
        if remainingPercentage <= 15 { return Color(red: 0.97, green: 0.37, blue: 0.19) }
        if remainingPercentage <= 30 { return .orange }
        if remainingPercentage <= 50 { return .yellow }
        if remainingPercentage <= 70 { return .mint }
        return .green
    }

    /// Returns a tint color for rate limit utilization percentage.
    /// - Parameter utilization: The utilization percentage (0-100)
    /// - Returns: Red (≥90%), Orange (≥70%), Secondary (otherwise)
    static func rateLimitTint(for utilization: Double) -> Color {
        if utilization >= 90 { return .red }
        if utilization >= AppConstants.warningThresholdPct { return .orange }
        return .secondary
    }

    /// Returns a 6-stage tint color for chart utilization display.
    /// - Parameter utilization: The utilization percentage (0-100)
    static func chartTint(for utilization: Double) -> Color {
        usageTint(for: max(0, 100 - utilization))
    }

    static let brandAccent = Color(red: 0.24, green: 0.46, blue: 0.96)
    static let surfaceElevated = Color.primary.opacity(0.05)
    static let dividerSubtle = Color.secondary.opacity(0.08)
}
