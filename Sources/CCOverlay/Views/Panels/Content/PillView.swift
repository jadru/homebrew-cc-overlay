import SwiftUI

struct PillView: View {
    let multiService: MultiProviderUsageService
    @Bindable var settings: AppSettings
    var onSizeChange: ((CGSize) -> Void)?

    @State private var isExpanded = false
    @State private var isHovered = false
    @State private var collapseTask: Task<Void, Never>?
    @State private var expandedSelectedProvider: CLIProvider?

    private var activeProviders: [CLIProvider] {
        multiService.activeProviders
    }

    /// The most critical provider data (lowest remaining % among usable providers).
    /// Providers at ≤5% are considered exhausted and deprioritized.
    private var criticalData: ProviderUsageData {
        let available = activeProviders
            .map { multiService.usageData(for: $0) }
            .filter(\.isAvailable)
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

    private var collapsedProviderSummary: String {
        activeProviders.map(\.shortLabel).joined(separator: " | ")
    }

    private var allProviderData: [(CLIProvider, ProviderUsageData)] {
        CLIProvider.allCases.map { ($0, multiService.usageData(for: $0)) }
    }

    private var activeProviderSet: Set<CLIProvider> {
        Set(activeProviders)
    }

    private var expandedSelectedData: ProviderUsageData {
        if let provider = expandedSelectedProvider {
            return multiService.usageData(for: provider)
        }
        return criticalData
    }

    var body: some View {
        contentCard
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: { $0.size }) { newSize in
                onSizeChange?(newSize)
            }
            .onHover(perform: handleHover)
            .onAppear {
                if settings.pillAlwaysExpanded {
                    isExpanded = true
                }
                syncExpandedSelection(with: activeProviders)
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
                withAnimation(DesignTokens.Animation.selection) {
                    isExpanded = alwaysExpanded || isHovered
                }
            }
            .onChange(of: multiService.activeProviders) { _, providers in
                syncExpandedSelection(with: providers)
                DebugFlowLogger.shared.log(
                    stage: .display,
                    message: "overlay.pill.providers.changed",
                    details: ["providers": providers.map(\.rawValue).joined(separator: ",")]
                )
            }
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
            if isExpanded {
                expandedDetails
            } else {
                pillHeader
            }
        }
        .padding(.horizontal, isExpanded ? 16 : 6)
        .padding(.vertical, isExpanded ? 14 : 4)
        .frame(maxWidth: isExpanded ? DesignTokens.Layout.expandedPillWidth : nil, alignment: .leading)
        .compatGlassRoundedRect(
            cornerRadius: isExpanded ? DesignTokens.CornerRadius.panel : 50,
            tint: tintColor.opacity(0.25)
        )
        .overlay(alignment: .topTrailing) {
            if isExpanded, isStale || (!settings.pillClickThrough && (isHovered || settings.pillAlwaysExpanded)) {
                overlayAccessoryCluster
                    .padding(.top, 8)
                    .padding(.trailing, 8)
            }
        }
        .animation(DesignTokens.Animation.selection, value: isExpanded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Overlay usage status")
        .accessibilityValue(accessibilityValue)
    }

    private var pillHeader: some View {
        HStack(spacing: 6) {
            compactSummaryHeader
            overlayAccessoryCluster
        }
    }

    private var compactSummaryHeader: some View {
        ProviderSummaryCardView(
            allProviderData: allProviderData,
            selectedProvider: $expandedSelectedProvider,
            activeProviders: activeProviderSet,
            size: .compact,
            showsCardBackground: false
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var overlayAccessoryCluster: some View {
        if isStale || (!settings.pillClickThrough && (isExpanded || isHovered || settings.pillAlwaysExpanded)) {
            HStack(spacing: 6) {
                if isStale {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                }

                if !settings.pillClickThrough && (isExpanded || isHovered || settings.pillAlwaysExpanded) {
                    pinButton
                }
            }
        }
    }

    private var pinButton: some View {
        Button(action: togglePinned) {
            Image(systemName: settings.pillAlwaysExpanded ? "pin.fill" : "pin")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(settings.pillAlwaysExpanded ? Color.brandAccent : .secondary)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .help(settings.pillAlwaysExpanded ? "Unpin expanded pill" : "Pin expanded pill")
        .accessibilityLabel(settings.pillAlwaysExpanded ? "Unpin expanded pill" : "Pin expanded pill")
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

    private func handleHover(_ hovering: Bool) {
        guard !settings.pillClickThrough else { return }
        guard !settings.pillAlwaysExpanded else { return }

        isHovered = hovering
        collapseTask?.cancel()

        if hovering {
            withAnimation(DesignTokens.Animation.selection) {
                isExpanded = true
            }
        } else {
            collapseTask = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(DesignTokens.Animation.selection) {
                        isExpanded = false
                    }
                }
            }
        }
    }

    private func togglePinned() {
        settings.pillAlwaysExpanded.toggle()
        withAnimation(DesignTokens.Animation.selection) {
            isExpanded = settings.pillAlwaysExpanded || isHovered
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

    @ViewBuilder
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            if activeProviders.isEmpty {
                Text("No active providers to display.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            } else {
                ProviderSummaryCardView(
                    allProviderData: allProviderData,
                    selectedProvider: $expandedSelectedProvider,
                    activeProviders: activeProviderSet
                )

                overlayDetailSection
            }

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

    // MARK: - Selected Provider Details

    @ViewBuilder
    private var overlayDetailSection: some View {
        let data = expandedSelectedData
        VStack(spacing: 12) {
            if data.isAvailable {
                selectedProviderGaugeCard(for: data)
                ProviderSessionDetailsView(data: data, size: .compact)
            }

            if let eq = data.enterpriseQuota, eq.isAvailable {
                enterpriseSeatSection(eq)
            }

            if !data.isAvailable {
                Text(data.provider.setupHint)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
            }
        }
    }

    private func selectedProviderGaugeCard(for data: ProviderUsageData) -> some View {
        let buckets: [GaugeCardView.RateLimitBucket] = data.rateLimitBuckets.map { bucket in
            .init(
                label: bucket.label,
                percentage: 100 - Int(min(bucket.utilization, 100)),
                showWarning: bucket.isWarning,
                dimmed: !bucket.isWarning
            )
        }

        let weeklyWarning: Int? = {
            if let weekly = data.rateLimitBuckets.first(where: { $0.isWarning }) {
                return Int(min(weekly.utilization, 100))
            }
            return nil
        }()

        return GaugeCardView(
            remainingPercentage: data.remainingPercentage,
            resetsAt: data.resetsAt,
            weeklyWarningPercentage: weeklyWarning,
            showLiveIndicator: true,
            rateLimitBuckets: buckets,
            predictionText: data.exhaustionPrediction?.formattedTimeRemaining,
            size: .compact,
            title: data.provider == .claudeCode ? "Session Left" : "\(data.primaryWindowLabel) Left"
        )
    }

    private func syncExpandedSelection(with providers: [CLIProvider]) {
        if let expandedSelectedProvider, CLIProvider.allCases.contains(expandedSelectedProvider) {
            return
        }

        expandedSelectedProvider = providers.first ?? criticalData.provider
    }

    private func dailyCostSection(cost: Double) -> some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(Color.dividerSubtle)
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

    private func enterpriseSeatSection(_ quota: EnterpriseQuota) -> some View {
        let remaining = quota.individualLimit.remainingDollars
        let remainPctSeat = quota.primaryRemainingPercentage

        return VStack(spacing: 6) {
            Rectangle()
                .fill(Color.dividerSubtle)
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
