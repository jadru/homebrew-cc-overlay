import AppKit
import SwiftUI

struct MenuBarView: View {
    let usageService: UsageDataService
    @Bindable var settings: AppSettings
    let sessionMonitor: SessionMonitor
    var onToggleOverlay: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 14) {
                headerSection
                primaryGaugeCard
                costCard
                tokenBreakdownCard
                activeSessionsCard
                controlsSection
                footerSection
            }
            .padding(16)
            .frame(width: 300)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Code")
                    .font(.system(size: 15, weight: .semibold))

                if let plan = usageService.detectedPlan {
                    Text(formatPlanName(plan))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text(settings.planTier.rawValue)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: { usageService.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .disabled(usageService.isLoading)
            .glassEffect(.regular.interactive(), in: .circle)
        }
    }

    // MARK: - Primary Gauge

    @ViewBuilder
    private var primaryGaugeCard: some View {
        if usageService.hasAPIData {
            apiGaugeCard
        } else {
            localGaugeCard
        }
    }

    @ViewBuilder
    private var apiGaugeCard: some View {
        let usage = usageService.oauthUsage
        let usedPct = usage.usedPercentage
        let remainPct = 100.0 - usedPct
        let tint = usageTintColor(remainPct)

        VStack(spacing: 10) {
            Text(windowLabel(usage.governingWindow))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: remainPct / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: remainPct)

                VStack(spacing: 2) {
                    Text(NumberFormatting.formatPercentage(remainPct))
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("remaining")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 88, height: 88)

            HStack(spacing: 8) {
                windowPill("5h", usage.fiveHour)
                windowPill("7d", usage.sevenDay)
                if let sonnet = usage.sevenDaySonnet {
                    windowPill("Sonnet", sonnet)
                }
            }

            HStack(spacing: 8) {
                if let resetsAt = usage.governingResetsAt {
                    Label {
                        Text("Resets \(resetsAt, style: .relative)")
                            .font(.system(size: 10))
                    } icon: {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 3) {
                    Circle().fill(.green).frame(width: 4, height: 4)
                    Text("Live").font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var localGaugeCard: some View {
        let usedPct = usageService.aggregatedUsage.usagePercentage(limit: settings.weightedCostLimit)
        let remainPct = 100.0 - usedPct
        let tint = usageTintColor(remainPct)

        VStack(spacing: 10) {
            Text("5-Hour Window (estimated)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: remainPct / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(NumberFormatting.formatPercentage(remainPct))
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("remaining")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 88, height: 88)
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    // MARK: - Cost Card

    @ViewBuilder
    private var costCard: some View {
        let fiveHourCost = usageService.aggregatedUsage.fiveHourCost
        let dailyCost = usageService.aggregatedUsage.dailyCost

        VStack(spacing: 8) {
            HStack {
                Text("Estimated Cost")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text(NumberFormatting.formatDollarCost(fiveHourCost.totalCost))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("5h window")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 1, height: 32)

                VStack(spacing: 3) {
                    Text(NumberFormatting.formatDollarCost(dailyCost.totalCost))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("today")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }

            if fiveHourCost.totalCost > 0 {
                HStack(spacing: 12) {
                    costChip("In", fiveHourCost.inputCost, .blue)
                    costChip("Out", fiveHourCost.outputCost, .purple)
                    costChip("CW", fiveHourCost.cacheWriteCost, .orange)
                    costChip("CR", fiveHourCost.cacheReadCost, .green)
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    // MARK: - Token Breakdown

    @ViewBuilder
    private var tokenBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            TokenBreakdownView(
                usage: usageService.aggregatedUsage.fiveHourWindow,
                title: "5-Hour Tokens"
            )
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    // MARK: - Active Sessions

    @ViewBuilder
    private var activeSessionsCard: some View {
        if sessionMonitor.hasActiveSessions {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Active Sessions")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 3) {
                        Circle().fill(.green).frame(width: 5, height: 5)
                        Text("\(sessionMonitor.activeSessionCount)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                }

                ForEach(sessionMonitor.activeSessions) { session in
                    if session.parentAppBundleId != nil {
                        Button {
                            activateParentApp(session)
                        } label: {
                            activeSessionRow(session)
                        }
                        .buttonStyle(.plain)
                    } else {
                        activeSessionRow(session)
                    }
                }
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func activeSessionRow(_ session: ActiveSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(formatDuration(session.duration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 8) {
                if let appName = session.parentAppName {
                    Label {
                        Text(appName)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "macwindow")
                            .font(.system(size: 9))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                }

                if let branch = session.gitBranch {
                    Label {
                        Text(branch)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                }

                if let count = session.messageCount {
                    Label {
                        Text("\(count) msgs")
                    } icon: {
                        Image(systemName: "message")
                            .font(.system(size: 9))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                }

                if let model = session.model {
                    Text(model)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func activateParentApp(_ session: ActiveSession) {
        guard let bundleId = session.parentAppBundleId else { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .first?.activate()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let hrs = mins / 60
        if hrs > 0 {
            return "\(hrs)h \(mins % 60)m"
        }
        return "\(mins)m"
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsSection: some View {
        HStack {
            Toggle("Overlay", isOn: Binding(
                get: { settings.showOverlay },
                set: {
                    settings.showOverlay = $0
                    onToggleOverlay?()
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            Spacer()

            Button {
                onOpenSettings?()
            } label: {
                Label("Settings", systemImage: "gear")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        VStack(spacing: 4) {
            if let lastRefresh = usageService.lastRefresh {
                Text("Updated \(lastRefresh, style: .relative) ago")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }

            if let error = usageService.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func windowPill(_ label: String, _ bucket: UsageBucket) -> some View {
        let pct = Int(min(bucket.utilization, 100))
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text("\(pct)%")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(
                    bucket.utilization >= 90 ? .red :
                    bucket.utilization >= 70 ? .orange : .secondary
                )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder
    private func costChip(_ label: String, _ amount: Double, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(label) \(NumberFormatting.formatDollarCost(amount))")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    private func usageTintColor(_ remainPct: Double) -> Color {
        if remainPct <= 10 { return .red }
        if remainPct <= 30 { return .orange }
        if remainPct <= 60 { return .yellow }
        return .green
    }

    private func windowLabel(_ window: String) -> String {
        switch window {
        case "five_hour": return "Session Limit"
        case "seven_day": return "Weekly Limit"
        default: return "Usage"
        }
    }

    private func formatPlanName(_ type: String) -> String {
        switch type {
        case "max_5": return "Max ($100/mo)"
        case "max_20": return "Max ($200/mo)"
        case "pro": return "Pro ($20/mo)"
        default: return type
        }
    }
}
