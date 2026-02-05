import SwiftUI

struct PillView: View {
    let usageService: UsageDataService
    let settings: AppSettings
    var onSizeChange: ((CGSize) -> Void)?

    @State private var isExpanded = false
    @State private var isHovered = false
    @State private var collapseTask: Task<Void, Never>?

    private var remainPct: Double {
        if usageService.hasAPIData {
            return usageService.remainingPercentage
        }
        return 100.0 - usageService.aggregatedUsage.usagePercentage(limit: settings.weightedCostLimit)
    }

    private var fiveHourCost: Double {
        usageService.aggregatedUsage.fiveHourCost.totalCost
    }

    private var dailyCost: Double {
        usageService.aggregatedUsage.dailyCost.totalCost
    }

    private var tintColor: Color {
        Color.usageTint(for: remainPct)
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
                // Always expanded mode: start expanded
                if settings.pillAlwaysExpanded {
                    isExpanded = true
                }
            }
            .onChange(of: settings.pillAlwaysExpanded) { _, alwaysExpanded in
                // React to setting change
                withAnimation(.snappy(duration: 0.25)) {
                    isExpanded = alwaysExpanded
                }
            }
    }

    private func handleHover(_ hovering: Bool) {
        // Click-through mode: ignore hover
        guard !settings.pillClickThrough else { return }

        // Always expanded mode: ignore hover (stay expanded)
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
        .frame(maxWidth: 260)
        .glassEffect(
            .regular.tint(tintColor.opacity(0.25)),
            in: .rect(cornerRadius: isExpanded ? 20 : 50)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
    }

    private var pillHeader: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tintColor)
                .frame(width: 6, height: 6)
                .animation(.easeInOut(duration: 0.3), value: tintColor)

            Text(NumberFormatting.formatPercentage(remainPct))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText(countsDown: true))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: remainPct)

            if isExpanded {
                Text("left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            } else if let resetsAt = sessionResetsAt, resetsAt > Date() {
                resetCountdown(resetsAt)
            }
        }
    }

    private var sessionResetsAt: Date? {
        guard usageService.hasAPIData else { return nil }
        return usageService.oauthUsage.primaryResetsAt
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
            // Gauge with 5-hour cost
            gaugeSection

            // Rate limit pills
            if usageService.hasAPIData {
                rateLimitSection
            }

            // Daily cost (optional)
            if settings.pillShowDailyCost && dailyCost > 0 {
                dailyCostSection
            }
        }
    }

    private var gaugeSection: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.1), lineWidth: 5)

            Circle()
                .trim(from: 0, to: remainPct / 100)
                .stroke(tintColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: remainPct)

            VStack(spacing: 2) {
                Text(NumberFormatting.formatDollarCompact(fiveHourCost))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Text("5h")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(width: 64, height: 64)
    }

    private var rateLimitSection: some View {
        let usage = usageService.oauthUsage
        return HStack(spacing: 6) {
            RatePillView(
                label: "5h",
                percentage: Int(min(usage.fiveHour.utilization, 100)),
                size: .compact
            )
            RatePillView(
                label: "7d",
                percentage: Int(min(usage.sevenDay.utilization, 100)),
                showWarningIcon: usage.isWeeklyNearLimit,
                size: .compact
            )
            .opacity(usage.isWeeklyNearLimit ? 1.0 : 0.5)
        }
    }

    private var dailyCostSection: some View {
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

                Text(NumberFormatting.formatDollarCost(dailyCost))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dailyCost)
            }
        }
    }
}
