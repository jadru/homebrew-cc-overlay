import SwiftUI

struct PillView: View {
    let usageService: UsageDataService
    let settings: AppSettings
    var onSizeChange: ((CGSize) -> Void)?

    @State private var isExpanded = false
    @State private var isHovered = false
    @State private var isSettingsPreview = false
    @State private var collapseTask: Task<Void, Never>?
    @State private var previewTask: Task<Void, Never>?
    @State private var hasAppeared = false

    private var remainPct: Double {
        if usageService.hasAPIData {
            return usageService.remainingPercentage
        }
        return 100.0 - usageService.aggregatedUsage.usagePercentage(limit: settings.weightedCostLimit)
    }

    private var fiveHourCost: Double {
        usageService.aggregatedUsage.fiveHourCost.totalCost
    }

    private var tintColor: Color {
        if remainPct <= 10 { return .red }
        if remainPct <= 30 { return .orange }
        if remainPct <= 60 { return .yellow }
        return .green
    }

    var body: some View {
        contentCard
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: { $0.size }) { newSize in
                onSizeChange?(newSize)
            }
            .onHover { hovering in
                guard !settings.clickThrough else { return }
                isHovered = hovering
                collapseTask?.cancel()
                if hovering {
                    withAnimation(.snappy(duration: 0.25)) {
                        isExpanded = true
                    }
                } else if !isSettingsPreview {
                    collapseTask = Task {
                        try? await Task.sleep(for: .milliseconds(150))
                        guard !Task.isCancelled else { return }
                        withAnimation(.snappy(duration: 0.25)) {
                            isExpanded = false
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    hasAppeared = true
                }
            }
            .onChange(of: settings.glassTintIntensity) { _, _ in expandForPreview() }
            .onChange(of: settings.overlayOpacity) { _, _ in expandForPreview() }
    }

    private func expandForPreview() {
        guard hasAppeared else { return }
        previewTask?.cancel()
        collapseTask?.cancel()
        isSettingsPreview = true
        withAnimation(.snappy(duration: 0.25)) { isExpanded = true }
        previewTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            isSettingsPreview = false
            if !isHovered {
                withAnimation(.snappy(duration: 0.25)) { isExpanded = false }
            }
        }
    }

    private var contentCard: some View {
        VStack(spacing: isExpanded ? 8 : 0) {
            pillHeader
            if isExpanded { expandedDetails }
        }
        .padding(.horizontal, isExpanded ? 14 : 10)
        .padding(.vertical, isExpanded ? 12 : 6)
        .frame(maxWidth: 260)
        .glassEffect(
            .regular.tint(tintColor.opacity(settings.glassTintIntensity)),
            in: .rect(cornerRadius: isExpanded ? 20 : 50)
        )
    }

    private var pillHeader: some View {
        HStack(spacing: 5) {
            Circle().fill(tintColor).frame(width: 6, height: 6)
            Text(NumberFormatting.formatPercentage(remainPct))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
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
            }
        }
    }

    private func formatCompactDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h\(String(format: "%02d", minutes))m" : "\(minutes)m"
    }

    private var expandedDetails: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: remainPct / 100)
                    .stroke(tintColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: remainPct)
                Text(NumberFormatting.formatDollarCompact(fiveHourCost))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, height: 56)
            .padding(.top, 2)

            if usageService.hasAPIData {
                let usage = usageService.oauthUsage
                HStack(spacing: 6) {
                    ratePill("5h", Int(min(usage.fiveHour.utilization, 100)))
                    if usage.isWeeklyNearLimit {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.orange)
                            ratePill("7d", Int(min(usage.sevenDay.utilization, 100)))
                        }
                    } else {
                        ratePill("7d", Int(min(usage.sevenDay.utilization, 100)))
                            .opacity(0.5)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func ratePill(_ label: String, _ pct: Int) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 8, weight: .medium)).foregroundStyle(.tertiary)
            Text("\(pct)%")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(pct >= 90 ? .red : pct >= 70 ? .orange : .secondary)
        }
    }
}
