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

    private struct BucketItem: Identifiable {
        let id: String
        let utilization: Double
    }

    private var bucketItems: [BucketItem] {
        guard let data = criticalData else {
            return [BucketItem(id: "5h", utilization: 0)]
        }
        return data.rateLimitBuckets.map { b in
            BucketItem(id: b.id, utilization: min(b.utilization, 100))
        }
    }

    private var isWeeklyWarning: Bool {
        guard let data = criticalData else { return false }
        return data.rateLimitBuckets.contains { $0.isWarning }
    }

    var body: some View {
        HStack(spacing: 4) {
            switch settings.menuBarIndicatorStyle {
            case .pieChart:
                miniGauge
            case .barChart:
                verticalBar
            case .percentage:
                if hasDualProviders {
                    dualProviderIcons
                } else if let data = criticalData {
                    Image(systemName: data.provider.iconName)
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 11))
                } else {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .symbolRenderingMode(.hierarchical)
                }
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

            if case .updateAvailable = updateService.updateState {
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: tintColor)
        .animation(.easeInOut(duration: 0.3), value: isWeeklyWarning)
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

    // MARK: - Pie Chart

    private var miniGauge: some View {
        if hasDualProviders {
            return AnyView(dualActivityRings)
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

    private var dualActivityRings: some View {
        let providers = multiService.activeProviders
        let outerData = providers.count > 0 ? multiService.usageData(for: providers[0]) : nil
        let innerData = providers.count > 1 ? multiService.usageData(for: providers[1]) : nil

        return ZStack {
            // Outer ring — first provider
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
            if let outer = outerData {
                Circle()
                    .trim(from: 0, to: outer.usedPercentage / 100)
                    .stroke(Color.chartTint(for: outer.usedPercentage), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: outer.usedPercentage)
            }

            // Inner ring — second provider
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                .frame(width: 8, height: 8)
            if let inner = innerData {
                Circle()
                    .trim(from: 0, to: inner.usedPercentage / 100)
                    .stroke(Color.chartTint(for: inner.usedPercentage), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: inner.usedPercentage)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: 14, height: 14)
    }

    // MARK: - Bar Chart

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
