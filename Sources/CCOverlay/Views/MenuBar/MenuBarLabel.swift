import SwiftUI

struct MenuBarLabel: View {
    let multiService: MultiProviderUsageService
    let settings: AppSettings
    let updateService: UpdateService

    /// The provider data with the lowest remaining % (most critical).
    private var criticalData: ProviderUsageData? {
        multiService.activeProviders
            .map { multiService.usageData(for: $0) }
            .filter { $0.isAvailable }
            .min { $0.remainingPercentage < $1.remainingPercentage }
    }

    private var remainPct: Double {
        criticalData?.remainingPercentage ?? 100
    }

    private var hasData: Bool {
        criticalData?.isAvailable ?? false
    }

    private var tintColor: Color {
        Color.usageTint(for: remainPct)
    }

    private var hasDualProviders: Bool {
        multiService.activeProviders.count > 1
    }

    private var isStale: Bool {
        guard let data = criticalData else { return false }
        return multiService.isStale(lastRefresh: data.lastRefresh)
    }

    private struct BucketItem: Identifiable {
        let id: String
        let utilization: Double
    }

    private var bucketItems: [BucketItem] {
        guard let data = criticalData else {
            return [BucketItem(id: "primary", utilization: 0)]
        }
        let items = data.rateLimitBuckets.map { b in
            BucketItem(id: b.id, utilization: min(b.utilization, 100))
        }
        return items.isEmpty ? [BucketItem(id: "primary", utilization: 0)] : items
    }

    private var isWeeklyWarning: Bool {
        guard let data = criticalData else { return false }
        return data.rateLimitBuckets.contains { $0.isWarning }
    }

    private var recentlyActive: [CLIProvider] {
        multiService.recentlyActiveProviders
    }

    var body: some View {
        HStack(spacing: 4) {
            switch settings.menuBarIndicatorStyle {
            case .pieChart:
                miniGauge
            case .barChart:
                verticalBar
            case .percentage:
                if hasDualProviders && !recentlyActive.isEmpty {
                    recentlyActiveIcons
                } else if hasDualProviders {
                    dualProviderIcons
                } else if let data = criticalData {
                    Image(systemName: data.provider.iconName)
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 11))
                } else {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .symbolRenderingMode(.hierarchical)
                }
                if hasData && recentlyActive.isEmpty {
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
                    .accessibilityHidden(true)
            }

            if isStale {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }

            if case .updateAvailable = updateService.updateState {
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isWeeklyWarning)
        .animation(.easeInOut(duration: 0.3), value: isStale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usage status")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard let data = criticalData, hasData else {
            return "No provider usage data available"
        }

        var value = "\(data.provider.rawValue), \(Int(data.remainingPercentage)) percent remaining"
        if isWeeklyWarning {
            value += ", warning threshold reached"
        }
        if isStale {
            value += ", data may be stale"
        }
        return value
    }

    // MARK: - Dual Provider Icons

    @ViewBuilder
    private var dualProviderIcons: some View {
        HStack(spacing: 2) {
            ForEach(multiService.activeProviders) { provider in
                let data = multiService.usageData(for: provider)
                Circle()
                    .fill(Color.usageTint(for: data.remainingPercentage))
                    .frame(width: 5, height: 5)
            }
        }
    }

    /// Recently active providers: icon + percentage, sorted by most consumed first.
    @ViewBuilder
    private var recentlyActiveIcons: some View {
        HStack(spacing: 3) {
            ForEach(recentlyActive, id: \.self) { provider in
                let data = multiService.usageData(for: provider)
                let tint = Color.usageTint(for: data.remainingPercentage)
                Image(systemName: provider.iconName)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 10))
                    .foregroundStyle(tint)
                Text(NumberFormatting.formatPercentage(data.remainingPercentage))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: data.remainingPercentage)
            }
        }
    }

    // MARK: - Pie Chart

    @ViewBuilder
    private var miniGauge: some View {
        if hasDualProviders {
            dualActivityRings
        } else {
            singleDonut
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

    private var dualActivityRings: some View {
        // Sort providers by enum order for stable ring identity
        let displayProviders = recentlyActive.isEmpty ? multiService.activeProviders : recentlyActive
        let sorted = displayProviders.sorted { a, b in
            let aIndex = CLIProvider.allCases.firstIndex(of: a) ?? Int.max
            let bIndex = CLIProvider.allCases.firstIndex(of: b) ?? Int.max
            return aIndex < bIndex
        }
        let outerPct = sorted.count > 0 ? multiService.usageData(for: sorted[0]).usedPercentage : 0.0
        let innerPct = sorted.count > 1 ? multiService.usageData(for: sorted[1]).usedPercentage : 0.0

        return ZStack {
            // Outer ring — first provider
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(outerPct / 100, 0.001))
                .stroke(Color.chartTint(for: outerPct), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: outerPct)

            // Inner ring — second provider
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                .frame(width: 8, height: 8)
            Circle()
                .trim(from: 0, to: max(innerPct / 100, 0.001))
                .stroke(Color.chartTint(for: innerPct), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: innerPct)
                .frame(width: 8, height: 8)
        }
        .frame(width: 14, height: 14)
    }

    // MARK: - Bar Chart

    @ViewBuilder
    private var verticalBar: some View {
        let items = bucketItems
        let barWidth: CGFloat = items.count > 1 ? 3 : 4
        let barSpacing: CGFloat = 1
        let barHeight: CGFloat = 14
        let cornerRadius: CGFloat = items.count > 1 ? 1 : 1.5

        HStack(spacing: barSpacing) {
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
