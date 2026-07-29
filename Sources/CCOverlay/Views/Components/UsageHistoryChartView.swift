import Charts
import SwiftUI

struct UsageHistoryChartView: View {
    let points: [UsageHistoryPoint]
    let forecast: ProviderHeadroomForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("7-day headroom", systemImage: "chart.xyaxis.line")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(forecast.label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(forecast.exhaustionAt == nil ? Color.secondary : Color.orange)
            }

            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Headroom", point.remainingPercentage)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.mint)

                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Headroom", point.remainingPercentage)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.mint.opacity(0.22), Color.mint.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 48)
                .accessibilityLabel("Seven day headroom history")
                .accessibilityValue(accessibilitySummary)
            } else {
                Text("Keep CC-Overlay running to build a private local trend.")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .compatGlassRoundedRect(cornerRadius: 10, interactive: false, tint: Color.mint.opacity(0.05))
    }

    private var accessibilitySummary: String {
        let latest = points.last?.remainingPercentage ?? 0
        return "\(Int(latest.rounded())) percent remaining. \(forecast.label)."
    }
}
