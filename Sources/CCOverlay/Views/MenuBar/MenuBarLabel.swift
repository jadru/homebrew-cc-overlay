import SwiftUI

struct MenuBarLabel: View {
    let usageService: UsageDataService
    let settings: AppSettings

    private struct BucketItem: Identifiable {
        let id: String
        let utilization: Double
    }

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

    private var isWeeklyWarning: Bool {
        let usage = usageService.oauthUsage
        guard usage.isAvailable else { return false }
        if usage.isWeeklyNearLimit { return true }
        if let sonnet = usage.sevenDaySonnet, sonnet.utilization >= 70 { return true }
        return false
    }

    private var bucketItems: [BucketItem] {
        guard usageService.hasAPIData else {
            let usagePct = usageService.aggregatedUsage.usagePercentage(limit: settings.weightedCostLimit)
            return [BucketItem(id: "5h", utilization: usagePct)]
        }
        let usage = usageService.oauthUsage
        var items: [BucketItem] = [
            BucketItem(id: "5h", utilization: min(usage.fiveHour.utilization, 100)),
            BucketItem(id: "7d", utilization: min(usage.sevenDay.utilization, 100)),
        ]
        if let sonnet = usage.sevenDaySonnet {
            items.append(BucketItem(id: "sonnet", utilization: min(sonnet.utilization, 100)))
        }
        return items
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

            if isWeeklyWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }

            if let eq = usageService.enterpriseQuota, eq.isAvailable {
                Text(NumberFormatting.formatDollarCompact(eq.individualLimit.remainingDollars))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color.usageTint(for: eq.primaryRemainingPercentage))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: eq.individualLimit.remainingDollars)
            } else if hasData {
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
        .animation(.easeInOut(duration: 0.3), value: isWeeklyWarning)
    }

    // MARK: - Pie Chart (Activity Ring)

    private var miniGauge: some View {
        let items = bucketItems
        if items.count >= 2 {
            return AnyView(activityRings(items: items))
        } else {
            return AnyView(singleDonut)
        }
    }

    private var singleDonut: some View {
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

    private func activityRings(items: [BucketItem]) -> some View {
        let outer = items[0]
        let inner = items[1]
        return ZStack {
            // Outer ring — 5h
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
            Circle()
                .trim(from: 0, to: outer.utilization / 100)
                .stroke(Color.chartTint(for: outer.utilization), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: outer.utilization)

            // Inner ring — 7d
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                .frame(width: 8, height: 8)
            Circle()
                .trim(from: 0, to: inner.utilization / 100)
                .stroke(Color.chartTint(for: inner.utilization), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: inner.utilization)
                .frame(width: 8, height: 8)
        }
        .frame(width: 14, height: 14)
    }

    // MARK: - Multi-Bar Chart

    private var verticalBar: some View {
        let items = bucketItems
        let barWidth: CGFloat = items.count > 1 ? 3 : 4
        let barSpacing: CGFloat = 1
        let barHeight: CGFloat = 14
        let cornerRadius: CGFloat = items.count > 1 ? 1 : 1.5

        return HStack(spacing: barSpacing) {
            ForEach(items) { item in
                singleBar(
                    utilization: item.utilization,
                    width: barWidth,
                    height: barHeight,
                    cornerRadius: cornerRadius
                )
            }
        }
    }

    private func singleBar(
        utilization: Double,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        let fillHeight = hasData ? height * (utilization / 100) : height
        let barColor = hasData ? Color.chartTint(for: utilization) : Color.secondary

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.secondary.opacity(0.3))
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(barColor)
                .frame(height: fillHeight)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: utilization)
        }
        .frame(width: width, height: height)
    }
}
