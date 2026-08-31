import Charts
import SwiftUI

struct AIUsageHistorySeries: Identifiable {
    let provider: CLIProvider
    let points: [UsageHistoryPoint]

    var id: CLIProvider { provider }

    var tint: Color {
        switch provider {
        case .codex: .brandAccent
        case .claudeCode: .orange
        }
    }
}

/// Shared 48-point, seven-day headroom chart for the dashboard and overlay.
struct AIUsageTrendChart: View {
    let series: [AIUsageHistorySeries]

    private var hasEnoughHistory: Bool {
        series.contains { $0.points.count >= 2 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Label("7-day AI headroom", systemImage: "chart.xyaxis.line")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                legend
            }

            if hasEnoughHistory {
                Chart {
                    ForEach(series) { item in
                        ForEach(item.points) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Headroom", point.remainingPercentage)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(item.tint)
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 48)
                .accessibilityLabel("Seven day AI headroom history")
                .accessibilityValue(accessibilitySummary)
            } else {
                Text("Keep CC-Overlay running to build a private local AI trend.")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .frame(height: 48, alignment: .center)
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var legend: some View {
        HStack(spacing: 6) {
            ForEach(series) { item in
                HStack(spacing: 3) {
                    Circle()
                        .fill(item.tint)
                        .frame(width: 5, height: 5)
                    Text(item.provider.rawValue)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var accessibilitySummary: String {
        series.compactMap { item in
            guard let latest = item.points.last else { return nil }
            return "\(item.provider.rawValue) \(Int(latest.remainingPercentage.rounded())) percent remaining"
        }
        .joined(separator: ", ")
    }
}
