import SwiftUI

struct MenuBarLabel: View {
    let usageService: UsageDataService
    let settings: AppSettings
    let sessionMonitor: SessionMonitor

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
        if remainPct <= 10 { return .red }
        if remainPct <= 30 { return .orange }
        if remainPct <= 60 { return .yellow }
        return .green
    }

    var body: some View {
        HStack(spacing: 4) {
            miniGauge

            if hasData {
                Text(NumberFormatting.formatPercentage(remainPct))
                    .font(.system(.caption, design: .monospaced))

                let cost = usageService.aggregatedUsage.fiveHourCost.totalCost
                if cost > 0 {
                    Text(NumberFormatting.formatDollarCompact(cost))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            if sessionMonitor.hasActiveSessions {
                HStack(spacing: 2) {
                    Circle().fill(.green).frame(width: 5, height: 5)
                    Text("\(sessionMonitor.activeSessionCount)")
                        .font(.system(.caption2, design: .monospaced))
                }
            }
        }
    }

    private var miniGauge: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)

            Circle()
                .trim(from: 0, to: hasData ? remainPct / 100 : 1.0)
                .stroke(hasData ? tintColor : .secondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 12, height: 12)
    }
}
