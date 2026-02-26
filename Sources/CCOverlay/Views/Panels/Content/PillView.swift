import SwiftUI

struct PillView: View {
    let multiService: MultiProviderUsageService
    let settings: AppSettings
    var onSizeChange: ((CGSize) -> Void)?

    @State private var isExpanded = false
    @State private var isHovered = false
    @State private var collapseTask: Task<Void, Never>?

    private var activeProviders: [CLIProvider] {
        multiService.activeProviders
    }

    /// The most critical provider data (lowest remaining % among usable providers).
    /// Providers at ≤5% are considered exhausted and deprioritized.
    private var criticalData: ProviderUsageData {
        let available = activeProviders
            .map { multiService.usageData(for: $0) }
            .filter { $0.isAvailable }
        let usable = available.filter { $0.remainingPercentage > 5 }
        return (usable.isEmpty ? available : usable)
            .min { $0.remainingPercentage < $1.remainingPercentage }
            ?? .empty(for: .claudeCode)
    }

    private var remainPct: Double {
        criticalData.remainingPercentage
    }

    private var tintColor: Color {
        Color.usageTint(for: remainPct)
    }

    private var isStale: Bool {
        multiService.isStale(lastRefresh: criticalData.lastRefresh)
    }

    var body: some View {
        contentCard
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: { $0.size }) { newSize in
                onSizeChange?(newSize)
            }
            .onHover { hovering in
                handleHover(hovering)
            }
            .onAppear {
                if settings.pillAlwaysExpanded {
                    isExpanded = true
                }
            }
            .onChange(of: settings.pillAlwaysExpanded) { _, alwaysExpanded in
                withAnimation(.snappy(duration: 0.25)) {
                    isExpanded = alwaysExpanded
                }
            }
    }

    private func handleHover(_ hovering: Bool) {
        guard !settings.pillClickThrough else { return }
        guard !settings.pillAlwaysExpanded else { return }

        isHovered = hovering
        collapseTask?.cancel()

        if hovering {
            withAnimation(.snappy(duration: 0.25)) {
                isExpanded = true
            }
        } else {
            collapseTask = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                withAnimation(.snappy(duration: 0.25)) {
                    isExpanded = false
                }
            }
        }
    }

    private var contentCard: some View {
        VStack(spacing: isExpanded ? 10 : 0) {
            pillHeader
            if isExpanded {
                expandedDetails
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .padding(.horizontal, isExpanded ? 16 : 10)
        .padding(.vertical, isExpanded ? 14 : 6)
        .frame(maxWidth: isExpanded ? 280 : nil)
        .compatGlassRoundedRect(
            cornerRadius: isExpanded ? 20 : 50,
            tint: tintColor.opacity(0.25)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Overlay usage status")
        .accessibilityValue(accessibilityValue)
    }

    // MARK: - Header

    private var pillHeader: some View {
        HStack(spacing: activeProviders.count > 1 ? 8 : 5) {
            if activeProviders.count > 1 {
                let recentlyActive = multiService.recentlyActiveProviders
                let critical = criticalData

                // Full display list: recently active (most consumed first) + critical if not already included
                let fullDisplay: [CLIProvider] = {
                    var list = recentlyActive
                    if !list.contains(critical.provider) {
                        list.append(critical.provider)
                    }
                    return list
                }()

                // Dim display: providers that are neither recently active nor critical
                let dimDisplay = activeProviders.filter { !fullDisplay.contains($0) }

                ForEach(fullDisplay, id: \.self) { provider in
                    providerFullChip(data: multiService.usageData(for: provider))
                }
                ForEach(dimDisplay, id: \.self) { provider in
                    providerDimChip(data: multiService.usageData(for: provider))
                }
            } else {
                // Single provider: colored shortLabel + percentage + time
                let data = criticalData
                Text(data.provider.shortLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.usageTint(for: data.remainingPercentage))
                    .animation(.easeInOut(duration: 0.3), value: data.remainingPercentage)

                Text(NumberFormatting.formatPercentage(remainPct))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: remainPct)

                if let resetsAt = data.resetsAt, resetsAt > Date() {
                    resetCountdown(resetsAt)
                }
            }

            if isStale {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
            }
        }
    }

    private var accessibilityValue: String {
        if activeProviders.isEmpty || !criticalData.isAvailable {
            return "No provider usage data available"
        }

        var value = "\(criticalData.provider.rawValue), \(Int(criticalData.remainingPercentage)) percent remaining"
        if isStale {
            value += ", data may be stale"
        }
        return value
    }

    /// Full display chip: shortLabel (colored) + percentage + reset countdown.
    @ViewBuilder
    private func providerFullChip(data: ProviderUsageData) -> some View {
        Text(data.provider.shortLabel)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color.usageTint(for: data.remainingPercentage))
            .animation(.easeInOut(duration: 0.3), value: data.remainingPercentage)

        Text(NumberFormatting.formatPercentage(data.remainingPercentage))
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .contentTransition(.numericText(countsDown: true))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: data.remainingPercentage)

        if let resetsAt = data.resetsAt, resetsAt > Date() {
            resetCountdown(resetsAt)
        }
    }

    /// Dim label chip: shortLabel only, reduced opacity.
    @ViewBuilder
    private func providerDimChip(data: ProviderUsageData) -> some View {
        Text(data.provider.shortLabel)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.usageTint(for: data.remainingPercentage))
            .opacity(0.7)
            .animation(.easeInOut(duration: 0.3), value: data.remainingPercentage)
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
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: remaining)
            }
        }
    }

    private func formatCompactDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h\(String(format: "%02d", minutes))m" : "\(minutes)m"
    }

    // MARK: - Expanded Details

    private var expandedDetails: some View {
        VStack(spacing: 12) {
            if activeProviders.count > 1 {
                verticalProviderRows
            } else {
                singleProviderGauge
            }

            // Daily cost (optional, aggregated across all providers)
            if settings.pillShowDailyCost {
                let totalDailyCost = activeProviders.reduce(0.0) { sum, provider in
                    sum + (multiService.usageData(for: provider).estimatedCost?.dailyCost ?? 0)
                }
                if totalDailyCost > 0 {
                    dailyCostSection(cost: totalDailyCost)
                }
            }
        }
    }

    // MARK: - Multi Provider (vertical rows)

    private var verticalProviderRows: some View {
        VStack(spacing: 10) {
            ForEach(activeProviders) { provider in
                let data = multiService.usageData(for: provider)
                providerRow(data: data)
            }
        }
    }

    private func providerRow(data: ProviderUsageData) -> some View {
        let barTint = Color.usageTint(for: data.remainingPercentage)

        return VStack(spacing: 4) {
            // Row: icon + label + progress bar + percentage + cost
            HStack(spacing: 6) {
                Image(systemName: data.provider.iconName)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text(data.provider.shortLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                        Capsule()
                            .fill(barTint)
                            .frame(width: max(geo.size.width * data.remainingPercentage / 100, 0))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: data.remainingPercentage)
                    }
                }
                .frame(height: 5)
                .clipShape(Capsule())

                Text(NumberFormatting.formatPercentage(data.remainingPercentage))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(barTint)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: data.remainingPercentage)

                if let cost = data.estimatedCost, cost.windowCost > 0 {
                    Text(NumberFormatting.formatDollarCompact(cost.windowCost))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }

            // Rate limit pills
            if !data.rateLimitBuckets.isEmpty {
                HStack(spacing: 6) {
                    ForEach(data.rateLimitBuckets) { bucket in
                        RatePillView(
                            label: bucket.label,
                            percentage: 100 - Int(min(bucket.utilization, 100)),
                            size: .compact
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Single Provider

    private var singleProviderGauge: some View {
        VStack(spacing: 12) {
            gaugeSection

            if criticalData.isAvailable, !criticalData.rateLimitBuckets.isEmpty {
                rateLimitSection
            }

            if let eq = criticalData.enterpriseQuota, eq.isAvailable {
                enterpriseSeatSection(eq)
            }
        }
    }

    private var gaugeSection: some View {
        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.1), lineWidth: 5)
            Circle()
                .trim(from: 0, to: remainPct / 100)
                .stroke(tintColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: remainPct)

            VStack(spacing: 2) {
                if let cost = criticalData.estimatedCost {
                    Text(NumberFormatting.formatDollarCompact(cost.windowCost))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                } else {
                    Text(NumberFormatting.formatPercentage(remainPct))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(countsDown: true))
                }

                Text(criticalData.estimatedCost != nil ? criticalData.primaryWindowLabel : "remaining")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(width: 64, height: 64)
    }

    private var rateLimitSection: some View {
        HStack(spacing: 8) {
            ForEach(criticalData.rateLimitBuckets) { bucket in
                RatePillView(
                    label: bucket.label,
                    percentage: 100 - Int(min(bucket.utilization, 100)),
                    showWarningIcon: bucket.isWarning,
                    size: .compact
                )
                .opacity(bucket.isWarning ? 1.0 : 0.5)
            }
        }
    }

    private func dailyCostSection(cost: Double) -> some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 0.5)
                .padding(.horizontal, 8)

            HStack {
                Text("Today")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(NumberFormatting.formatDollarCost(cost))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cost)
            }
        }
    }

    // MARK: - Enterprise Seat

    private func enterpriseSeatSection(_ quota: EnterpriseQuota) -> some View {
        let remaining = quota.individualLimit.remainingDollars
        let remainPctSeat = quota.primaryRemainingPercentage

        return VStack(spacing: 6) {
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 0.5)
                .padding(.horizontal, 8)

            HStack {
                Image(systemName: "building.2")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text("Seat")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("\(NumberFormatting.formatDollarCompact(remaining)) left")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.usageTint(for: remainPctSeat))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: remaining)
            }
        }
    }
}
