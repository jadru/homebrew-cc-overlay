import SwiftUI

struct MenuBarLabel: View {
    let usageService: UsageDataService
    let settings: AppSettings

    private var remainPct: Double {
        if usageService.hasAPIData {
            return usageService.remainingPercentage
        }
        return 100.0 - usageService.aggregatedUsage.usagePercentage(limit: settings.weightedCostLimit)
    }

    private var hasData: Bool {
        usageService.hasAPIData || usageService.aggregatedUsage.fiveHourWindow.totalTokens > 0
    }

    private var tintColor: Color {
        Color.usageTint(for: remainPct)
    }

    var body: some View {
        HStack(spacing: 4) {
            switch settings.menuBarIndicatorStyle {
            case .pieChart:
                miniGauge
            case .barChart:
                verticalBar
            case .percentage:
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .symbolRenderingMode(.hierarchical)
                if hasData {
                    Text(NumberFormatting.formatPercentage(remainPct))
                        .font(.system(.caption, design: .monospaced))
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: remainPct)
                }
            }

            if hasData {
                let cost = usageService.aggregatedUsage.fiveHourCost.totalCost
                if cost > 0 {
                    Text(NumberFormatting.formatDollarCompact(cost))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cost)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: tintColor)
    }

    // MARK: - Pie Chart (Donut Gauge)

    private var miniGauge: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)

            Circle()
                .trim(from: 0, to: hasData ? remainPct / 100 : 1.0)
                .stroke(hasData ? tintColor : .secondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: remainPct)
        }
        .frame(width: 12, height: 12)
    }

    // MARK: - Vertical Bar

    private var verticalBar: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.secondary.opacity(0.3))

            RoundedRectangle(cornerRadius: 1.5)
                .fill(hasData ? tintColor : .secondary)
                .frame(height: hasData ? 14 * (remainPct / 100) : 14)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: remainPct)
        }
        .frame(width: 4, height: 14)
    }
}
