import SwiftUI

struct PillView: View {
    let multiService: MultiProviderUsageService
    @Bindable var settings: AppSettings
    var onSizeChange: ((CGSize) -> Void)?

    @State private var isExpanded = false
    @State private var isHovered = false
    @State private var collapseTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace

    private var activeProviders: [CLIProvider] {
        multiService.activeProviders
    }

    /// The most critical provider data (lowest remaining % among usable providers).
    /// Providers at <=5% are considered exhausted and deprioritized.
    private var criticalData: ProviderUsageData {
        let available = activeProviders
            .map { multiService.usageData(for: $0) }
            .filter(\.isAvailable)
        let usable = available.filter { $0.remainingPercentage > 5 }
        return (usable.isEmpty ? available : usable)
            .min { $0.remainingPercentage < $1.remainingPercentage }
            ?? .empty(for: .claudeCode)
    }

    private var visibleProviders: [CLIProvider] {
        Self.visibleOverlayProviders(
            activeProviders: activeProviders,
            recentlyActiveProviders: multiService.recentlyActiveProviders,
            usageData: multiService.usageData(for:)
        )
    }

    private var remainPct: Double {
        criticalData.isAvailable ? criticalData.remainingPercentage : 100
    }

    private var tintColor: Color {
        criticalData.isAvailable ? Color.usageTint(for: remainPct) : Color.brandAccent
    }

    private var isStale: Bool {
        multiService.isStale(lastRefresh: criticalData.lastRefresh)
    }

    private var expansionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : DesignTokens.Animation.selection
    }

    private var primaryValueText: String {
        guard criticalData.isAvailable else { return "Setup" }
        let prefix = criticalData.isEstimated ? "~" : ""
        return "\(prefix)\(NumberFormatting.formatPercentage(criticalData.remainingPercentage))"
    }

    private var primaryCaptionText: String {
        if criticalData.isAvailable {
            let estimate = criticalData.isEstimated ? "est. " : ""
            return "\(criticalData.provider.shortLabel) \(estimate)\(criticalData.primaryWindowLabel)"
        }
        return "CLI"
    }

    var body: some View {
        Group {
            if !visibleProviders.isEmpty {
                contentSurface
            }
        }
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: { $0.size }) { newSize in
                onSizeChange?(newSize)
            }
            .onHover(perform: handleHover)
            .onAppear {
                if settings.pillAlwaysExpanded {
                    isExpanded = true
                }
                DebugFlowLogger.shared.log(
                    stage: .display,
                    message: "overlay.pill.appear",
                    details: [
                        "providers": activeProviders.map(\.rawValue).joined(separator: ","),
                        "expanded": "\(isExpanded)",
                    ]
                )
            }
            .onDisappear {
                collapseTask?.cancel()
                DebugFlowLogger.shared.log(stage: .display, message: "overlay.pill.disappear")
            }
            .onChange(of: settings.pillAlwaysExpanded) { _, alwaysExpanded in
                withAnimation(expansionAnimation) {
                    isExpanded = alwaysExpanded || isHovered
                }
            }
            .onChange(of: multiService.activeProviders) { _, providers in
                DebugFlowLogger.shared.log(
                    stage: .display,
                    message: "overlay.pill.providers.changed",
                    details: ["providers": providers.map(\.rawValue).joined(separator: ",")]
                )
            }
    }

    private var contentSurface: some View {
        Group {
            glassSurfaceGroup
        }
        .animation(expansionAnimation, value: isExpanded)
        .accessibilityElement(children: isExpanded ? .contain : .combine)
        .accessibilityLabel("Overlay usage status")
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var glassSurfaceGroup: some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 14) {
                commandSurfaceState
            }
        } else {
            commandSurfaceState
        }
        #else
        commandSurfaceState
        #endif
    }

    @ViewBuilder
    private var commandSurfaceState: some View {
        if isExpanded {
            expandedCommandSurface
                .transition(commandSurfaceTransition)
                .compatGlassEffectID("overlay-surface", in: glassNamespace)
        } else {
            collapsedCommandPill
                .transition(commandSurfaceTransition)
                .compatGlassEffectID("overlay-surface", in: glassNamespace)
        }
    }

    private var collapsedCommandPill: some View {
        let buckets = Self.overlayWindowBuckets(for: criticalData)

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                compactProviderGlyph(criticalData.provider, data: criticalData)

                VStack(alignment: .leading, spacing: 0) {
                    Text(primaryValueText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .contentTransition(.numericText())

                    Text(primaryCaptionText)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .frame(minWidth: 38, alignment: .leading)

                Spacer(minLength: 3)

                if let resetsAt = criticalData.resetsAt, criticalData.isAvailable {
                    resetCountdown(resetsAt)
                } else if isStale {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.yellow)
                }
            }

            if !buckets.isEmpty {
                compactRateWindowMeters(buckets)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minWidth: buckets.count > 1 ? 174 : 106, minHeight: buckets.isEmpty ? 30 : 42, alignment: .leading)
        .compatGlassRoundedRect(
            cornerRadius: 8,
            interactive: !settings.pillClickThrough,
            tint: tintColor.opacity(0.23)
        )
    }

    private var commandSurfaceTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .topTrailing))
        )
    }

    private var expandedCommandSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            commandHeader
            if visibleProviders.count == 1 {
                singleProviderRateWindows
            } else {
                providerRows
            }
        }
        .padding(12)
        .frame(width: DesignTokens.Layout.expandedPillWidth, alignment: .leading)
        .compatGlassRoundedRect(
            cornerRadius: 12,
            interactive: !settings.pillClickThrough,
            tint: tintColor.opacity(0.22)
        )
    }

    private var commandHeader: some View {
        HStack(spacing: 10) {
            providerGlyph(criticalData.provider, data: criticalData, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(primaryValueText)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .contentTransition(.numericText())

                    if criticalData.isAvailable {
                        Text(criticalData.isEstimated ? "estimate" : "left")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(headerSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if isStale {
                    staleBadge
                }
                if let resetsAt = criticalData.resetsAt, criticalData.isAvailable {
                    resetCountdown(resetsAt)
                }
            }
        }
        .frame(minHeight: 42)
    }

    private var headerSubtitle: String {
        if criticalData.isAvailable {
            if let prediction = criticalData.exhaustionPrediction?.formattedTimeRemaining {
                return prediction
            }
            let source = criticalData.isEstimated ? "local estimate" : criticalData.primaryWindowLabel
            return "\(criticalData.provider.rawValue) - \(source)"
        }
        return "Install a supported CLI to start tracking usage"
    }

    private var providerRows: some View {
        VStack(spacing: 7) {
            ForEach(visibleProviders) { provider in
                providerStatusRow(provider)
            }
        }
    }

    @ViewBuilder
    private var singleProviderRateWindows: some View {
        let buckets = Self.overlayWindowBuckets(for: criticalData)

        if buckets.isEmpty {
            usageBar(for: criticalData)
                .frame(height: 6)
        } else {
            rateWindowPaceGrid(buckets)
        }
    }

    private func providerStatusRow(_ provider: CLIProvider) -> some View {
        let data = multiService.usageData(for: provider)
        let buckets = Self.overlayWindowBuckets(for: data)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                providerGlyph(provider, data: data, size: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.rawValue)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(data.isAvailable ? .primary : .secondary)

                    Text(rowStatusText(for: data))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 8)

                Text("\(data.isEstimated ? "~" : "")\(NumberFormatting.formatPercentage(data.remainingPercentage))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.usageTint(for: data.remainingPercentage))
                    .frame(width: 42, alignment: .trailing)
                    .contentTransition(.numericText())
            }

            if buckets.isEmpty {
                usageBar(for: data)
            } else {
                rateWindowPaceGrid(buckets)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(minHeight: buckets.isEmpty ? 40 : 68)
    }

    private func rowStatusText(for data: ProviderUsageData) -> String {
        if let cost = data.estimatedCost, cost.dailyCost > 0 {
            return "\(data.primaryWindowLabel) - \(NumberFormatting.formatDollarCompact(cost.dailyCost)) today"
        }
        if let plan = data.planName {
            return "\(data.primaryWindowLabel) - \(plan)"
        }
        return data.primaryWindowLabel
    }

    private func usageBar(for data: ProviderUsageData) -> some View {
        GeometryReader { proxy in
            let progress = data.isAvailable ? min(max(data.remainingPercentage / 100, 0), 1) : 0
            let width = proxy.size.width * progress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                Capsule()
                    .fill(data.isAvailable ? Color.usageTint(for: data.remainingPercentage) : Color.secondary.opacity(0.18))
                    .frame(width: max(width, data.isAvailable ? 3 : 0))
            }
        }
        .frame(height: 4)
    }

    private func rateWindowPaceGrid(_ buckets: [OverlayWindowBucket]) -> some View {
        HStack(spacing: 10) {
            ForEach(buckets) { bucket in
                OverlayRateWindowPaceView(
                    label: bucket.label,
                    utilization: bucket.utilization,
                    resetsAt: bucket.resetsAt
                )
            }
        }
    }

    private func compactRateWindowMeters(_ buckets: [OverlayWindowBucket]) -> some View {
        HStack(spacing: 4) {
            ForEach(buckets) { bucket in
                compactRateWindowMeter(bucket)
            }
        }
    }

    private func compactRateWindowMeter(_ bucket: OverlayWindowBucket) -> some View {
        let pace = RateWindowPace.assess(
            label: bucket.label,
            utilization: bucket.utilization,
            resetsAt: bucket.resetsAt
        )
        let tint = Color.chartTint(for: pace.utilization)

        return HStack(spacing: 3) {
            Text(bucket.label)
                .font(.system(size: 7, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)

            GeometryReader { proxy in
                let usedWidth = proxy.size.width * CGFloat(pace.utilization / 100)
                let expectedOffset = proxy.size.width * CGFloat(pace.expectedUtilization / 100)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))

                    Capsule()
                        .fill(tint)
                        .frame(width: max(usedWidth, pace.utilization > 0 ? 1.5 : 0))

                    if pace.status != .unavailable {
                        Rectangle()
                            .fill(Color.primary.opacity(0.4))
                            .frame(width: 1, height: 5)
                            .offset(x: min(max(expectedOffset, 0), max(proxy.size.width - 1, 0)))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 2)

            Text("\(bucket.percentage)%")
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .frame(width: 20, alignment: .trailing)
                .contentTransition(.numericText())
        }
        .frame(width: 75)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bucket.label) window")
        .accessibilityValue("\(bucket.percentage) percent remaining")
    }

    private func providerGlyph(_ provider: CLIProvider, data: ProviderUsageData, size: CGFloat) -> some View {
        let color = data.isAvailable ? Color.usageTint(for: data.remainingPercentage) : Color.secondary

        return ZStack {
            Circle()
                .fill(color.opacity(data.isAvailable ? 0.18 : 0.08))
                .overlay(
                    Circle()
                        .strokeBorder(color.opacity(data.isAvailable ? 0.45 : 0.18), lineWidth: 0.8)
                )

            ProviderIconView(
                provider: provider,
                size: max(size * 0.48, 10),
                fallbackColor: color
            )
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(data.isAvailable ? color : Color.secondary.opacity(0.5))
                .frame(width: max(size * 0.22, 5), height: max(size * 0.22, 5))
                .overlay(Circle().stroke(Color.primary.opacity(0.14), lineWidth: 0.6))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func compactProviderGlyph(_ provider: CLIProvider, data: ProviderUsageData) -> some View {
        let color = data.isAvailable ? Color.usageTint(for: data.remainingPercentage) : Color.secondary

        return ProviderIconView(
            provider: provider,
            size: 14,
            fallbackColor: color
        )
        .frame(width: 17, height: 17)
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(data.isAvailable ? color : Color.secondary.opacity(0.5))
                .frame(width: 4, height: 4)
                .overlay(Circle().stroke(Color.primary.opacity(0.14), lineWidth: 0.5))
        }
        .accessibilityHidden(true)
    }

    private var staleBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 9, weight: .semibold))
            Text("Stale")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.yellow)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .compatGlassCapsule(tint: Color.yellow.opacity(0.14))
    }

    private var accessibilityValue: String {
        if activeProviders.isEmpty || !criticalData.isAvailable {
            return "No provider usage data available"
        }

        var value = "\(criticalData.provider.rawValue), \(Int(criticalData.remainingPercentage)) percent remaining"
        if criticalData.isEstimated {
            value += ", local estimate"
        }
        if isStale {
            value += ", data may be stale"
        }
        return value
    }

    private func handleHover(_ hovering: Bool) {
        guard !settings.pillClickThrough else { return }
        guard !settings.pillAlwaysExpanded else { return }

        isHovered = hovering
        collapseTask?.cancel()

        if hovering {
            withAnimation(expansionAnimation) {
                isExpanded = true
            }
        } else {
            collapseTask = Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 110))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(expansionAnimation) {
                        isExpanded = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resetCountdown(_ resetsAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let remaining = resetsAt.timeIntervalSince(context.date)
            if remaining > 0 {
                Text(formatCompactDuration(remaining))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText(countsDown: true))
            }
        }
    }

    private func formatCompactDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h\(String(format: "%02d", minutes))m" : "\(minutes)m"
    }

    struct OverlayWindowBucket: Identifiable {
        let id: String
        let label: String
        let percentage: Int
        let utilization: Double
        let resetsAt: Date?
        let showWarning: Bool
    }

    static func overlayWindowBuckets(for data: ProviderUsageData) -> [OverlayWindowBucket] {
        guard data.isAvailable else { return [] }

        var seen = Set<String>()
        return data.rateLimitBuckets.compactMap { bucket in
            guard let label = overlayWindowLabel(bucket.label),
                  seen.insert(label).inserted
            else { return nil }

            let remaining = max(0, min(100, 100 - bucket.utilization))
            return OverlayWindowBucket(
                id: label,
                label: label,
                percentage: Int(remaining.rounded()),
                utilization: min(max(bucket.utilization, 0), 100),
                resetsAt: bucket.resetsAt,
                showWarning: bucket.isWarning
            )
        }
    }

    static func visibleOverlayProviders(
        activeProviders: [CLIProvider],
        recentlyActiveProviders: [CLIProvider],
        usageData: (CLIProvider) -> ProviderUsageData
    ) -> [CLIProvider] {
        var seen = Set<CLIProvider>()
        return (recentlyActiveProviders + activeProviders).filter { provider in
            seen.insert(provider).inserted && usageData(provider).isAvailable
        }
    }

    private static func overlayWindowLabel(_ label: String) -> String? {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "5h": return "5H"
        case "1w", "7d": return "7D"
        default: return nil
        }
    }

}
