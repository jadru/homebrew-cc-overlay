import AppKit
import SwiftUI

struct MenuBarLabel: View {
    let multiService: MultiProviderUsageService
    let settings: AppSettings
    let updateService: UpdateService

    @State private var pulsePhase = false

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
        let remainingPercentage: Double
    }

    private var bucketItems: [BucketItem] {
        let activeItems = multiService.activeProviders
            .sorted { a, b in
                let aIndex = CLIProvider.allCases.firstIndex(of: a) ?? Int.max
                let bIndex = CLIProvider.allCases.firstIndex(of: b) ?? Int.max
                return aIndex < bIndex
            }
            .map { provider in
                let data = multiService.usageData(for: provider)
                return BucketItem(
                    id: provider.rawValue,
                    remainingPercentage: data.isAvailable ? min(data.remainingPercentage, 100) : 0
                )
            }

        if !activeItems.isEmpty {
            return activeItems
        }

        guard let data = criticalData else {
            return [BucketItem(id: "primary", remainingPercentage: 0)]
        }
        return [BucketItem(id: "primary", remainingPercentage: min(data.remainingPercentage, 100))]
    }

    private var isWeeklyWarning: Bool {
        guard let data = criticalData else { return false }
        return data.rateLimitBuckets.contains { $0.isWarning }
    }

    private var recentlyActive: [CLIProvider] {
        multiService.recentlyActiveProviders
    }

    private var isLowRemaining: Bool {
        hasData && remainPct < 20
    }

    private var menuBarForegroundNSColor: NSColor {
        let appearance = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return appearance == .darkAqua ? .white : .black
    }

    private var menuBarForegroundColor: Color {
        Color(nsColor: menuBarForegroundNSColor)
    }

    @ViewBuilder
    private var indicatorView: some View {
        switch settings.menuBarIndicatorStyle {
        case .pieChart:
            Image(nsImage: renderedPieChartImage())
                .frame(width: hasDualProviders ? 14 : 13, height: hasDualProviders ? 14 : 13)
                .fixedSize()
        case .barChart:
            Image(nsImage: renderedBarChartImage())
                .frame(minWidth: hasDualProviders ? 9 : 5, minHeight: 16)
                .fixedSize()
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
    }

    var body: some View {
        HStack(spacing: 4) {
            indicatorView
            .id(settings.menuBarIndicatorStyle.rawValue)
            .frame(minWidth: 14, minHeight: 14, alignment: .center)
            .scaleEffect(isLowRemaining && pulsePhase ? 1.05 : 1.0)
            .opacity(isLowRemaining && pulsePhase ? 0.78 : 1.0)

            if isWeeklyWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(menuBarForegroundColor.opacity(0.9))
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }

            if isStale {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 9))
                    .foregroundStyle(menuBarForegroundColor.opacity(0.72))
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }

            if case .updateAvailable = updateService.updateState {
                Circle()
                    .fill(menuBarForegroundColor.opacity(0.88))
                    .frame(width: 6, height: 6)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isWeeklyWarning)
        .animation(.easeInOut(duration: 0.3), value: isStale)
        .padding(.horizontal, 2)
        .frame(height: 16)
        .fixedSize()
        .onAppear(perform: updatePulseState)
        .onChange(of: isLowRemaining) { _, _ in
            updatePulseState()
        }
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
                Circle()
                    .fill(menuBarForegroundColor.opacity(0.9))
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
                Image(systemName: provider.iconName)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 10))
                    .foregroundStyle(menuBarForegroundColor)
                Text(NumberFormatting.formatPercentage(data.remainingPercentage))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(menuBarForegroundColor)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: data.remainingPercentage)
            }
        }
    }

    // MARK: - Pie Chart

    @ViewBuilder
    private var miniGauge: some View {
        singleDonut
    }

    private var singleDonut: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.22), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: hasData ? max(remainPct / 100, 0.001) : 1.0)
                .stroke(hasData ? tintColor : Color.primary.opacity(0.55), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: remainPct)
        }
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
                .stroke(Color.primary.opacity(0.18), lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(outerPct / 100, 0.001))
                .stroke(Color.chartTint(for: outerPct), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: outerPct)

            // Inner ring — second provider
            Circle()
                .stroke(Color.primary.opacity(0.18), lineWidth: 2)
                .frame(width: 8, height: 8)
            Circle()
                .trim(from: 0, to: max(innerPct / 100, 0.001))
                .stroke(Color.chartTint(for: innerPct), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: innerPct)
                .frame(width: 8, height: 8)

            Circle()
                .fill(tintColor)
                .frame(width: 3.5, height: 3.5)
        }
    }

    // MARK: - Bar Chart

    @ViewBuilder
    private var verticalBar: some View {
        let items = bucketItems
        let barWidth: CGFloat = items.count > 1 ? 3.5 : 4.5
        let barSpacing: CGFloat = 1.25
        let barHeight: CGFloat = 16
        let cornerRadius: CGFloat = items.count > 1 ? 1.25 : 1.75

        HStack(spacing: barSpacing) {
            ForEach(items) { item in
                singleBar(
                    remainingPercentage: item.remainingPercentage,
                    width: barWidth,
                    height: barHeight,
                    cornerRadius: cornerRadius
                )
            }
        }
    }

    private func singleBar(
        remainingPercentage: Double,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        let fillHeight = hasData ? height * (remainingPercentage / 100) : height

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.primary.opacity(0.22))
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(menuBarForegroundColor)
                .frame(height: fillHeight)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: remainingPercentage)
        }
        .frame(width: width, height: height)
    }

    private func updatePulseState() {
        if isLowRemaining {
            guard pulsePhase == false else { return }
            withAnimation(DesignTokens.Animation.pulse) {
                pulsePhase = true
            }
        } else {
            pulsePhase = false
        }
    }

    private func renderedPieChartImage() -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = true
        }

        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 1.4, dy: 1.4)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2

        let track = NSBezierPath(ovalIn: rect)
        track.lineWidth = 2.4
        NSColor.black.withAlphaComponent(0.28).setStroke()
        track.stroke()

        let progress = hasData ? max(min(remainPct / 100, 1.0), 0.02) : 1.0
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - (360 * progress),
            clockwise: true
        )
        arc.lineWidth = 2.4
        arc.lineCapStyle = .round
        NSColor.black.setStroke()
        arc.stroke()

        return image
    }

    private func renderedBarChartImage() -> NSImage {
        let bars = Array(bucketItems.prefix(3))
        let barCount = max(bars.count, 1)
        let barWidth: CGFloat = barCount > 1 ? 3.2 : 4.2
        let spacing: CGFloat = 1.4
        let height: CGFloat = 15
        let imageWidth = (CGFloat(barCount) * barWidth) + (CGFloat(barCount - 1) * spacing) + 1
        let image = NSImage(size: NSSize(width: imageWidth, height: height))
        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = true
        }

        let items = bars.isEmpty ? [BucketItem(id: "primary", remainingPercentage: 0)] : bars
        for (index, item) in items.enumerated() {
            let x = CGFloat(index) * (barWidth + spacing)
            let trackRect = NSRect(x: x, y: 0, width: barWidth, height: height)
            let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 1.6, yRadius: 1.6)
            NSColor.black.withAlphaComponent(0.28).setFill()
            trackPath.fill()

            let fillHeight = hasData ? max((height * CGFloat(item.remainingPercentage / 100.0)).rounded(.toNearestOrAwayFromZero), 1) : height
            let fillRect = NSRect(x: x, y: 0, width: barWidth, height: fillHeight)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 1.6, yRadius: 1.6)
            NSColor.black.setFill()
            fillPath.fill()
        }

        return image
    }
}
