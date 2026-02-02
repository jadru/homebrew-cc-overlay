import SwiftUI

struct OverlayView: View {
    let usageService: UsageDataService
    let settings: AppSettings
    let sessionMonitor: SessionMonitor
    var onSizeChange: ((CGSize) -> Void)?

    @State private var isExpanded = false

    private var remainPct: Double {
        if usageService.hasAPIData {
            return usageService.remainingPercentage
        }
        return 100.0 - usageService.aggregatedUsage.usagePercentage(limit: settings.weightedCostLimit)
    }

    private var usedPct: Double { 100.0 - remainPct }

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
            .onHover { hovering in
                guard !settings.clickThrough else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    isExpanded = hovering
                }
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                onSizeChange?(size)
            }
    }

    // MARK: - Card

    private var contentCard: some View {
        VStack(spacing: isExpanded ? 8 : 0) {
            // Pill header — always visible
            pillHeader

            // Expanded details — unfold below the pill
            if isExpanded {
                expandedDetails
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, isExpanded ? 14 : 10)
        .padding(.vertical, isExpanded ? 12 : 6)
        .glassEffect(
            .regular.tint(tintColor.opacity(0.25)),
            in: .rect(cornerRadius: isExpanded ? 20 : 50)
        )
    }

    // MARK: - Pill Header

    private var pillHeader: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tintColor)
                .frame(width: 6, height: 6)

            Text(NumberFormatting.formatPercentage(remainPct))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            if isExpanded {
                Text("left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Expanded Details

    private var expandedDetails: some View {
        VStack(spacing: 8) {
            // Gauge ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: remainPct / 100)
                    .stroke(
                        tintColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: remainPct)

                Text(NumberFormatting.formatDollarCompact(fiveHourCost))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, height: 56)
            .padding(.top, 2)

            // Active sessions
            if sessionMonitor.hasActiveSessions {
                HStack(spacing: 3) {
                    Circle().fill(.green).frame(width: 4, height: 4)
                    Text("\(sessionMonitor.activeSessionCount) active")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Rate limit windows
            if usageService.hasAPIData {
                let usage = usageService.oauthUsage
                HStack(spacing: 6) {
                    ratePill("5h", Int(min(usage.fiveHour.utilization, 100)))
                    ratePill("7d", Int(min(usage.sevenDay.utilization, 100)))
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func ratePill(_ label: String, _ pct: Int) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.tertiary)
            Text("\(pct)%")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(
                    pct >= 90 ? .red : pct >= 70 ? .orange : .secondary
                )
        }
    }
}
