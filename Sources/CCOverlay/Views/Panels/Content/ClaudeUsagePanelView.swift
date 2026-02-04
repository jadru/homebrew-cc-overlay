import SwiftUI

struct ClaudeUsagePanelView: View {
    let usageService: UsageDataService
    let settings: AppSettings

    private var remainPct: Double {
        if usageService.hasAPIData {
            return usageService.remainingPercentage
        }
        return 100.0 - usageService.aggregatedUsage.usagePercentage(limit: settings.weightedCostLimit)
    }

    private var tintColor: Color {
        if remainPct <= 10 { return .red }
        if remainPct <= 30 { return .orange }
        if remainPct <= 60 { return .yellow }
        return .green
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                gaugeSection
                costSection
                tokenSection
                if usageService.hasAPIData {
                    rateLimitSection
                }
            }
            .padding(12)
        }
    }

    // MARK: - Gauge

    @ViewBuilder
    private var gaugeSection: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.08), lineWidth: 5)

                Circle()
                    .trim(from: 0, to: remainPct / 100)
                    .stroke(
                        tintColor.gradient,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: remainPct)

                VStack(spacing: 1) {
                    Text(NumberFormatting.formatPercentage(remainPct))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(tintColor)

                    Text("remaining")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(width: 68, height: 68)

            Text("Session Limit")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            if let resetsAt = usageService.oauthUsage.primaryResetsAt, resetsAt > Date() {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text("Resets \(resetsAt, style: .relative)")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.quaternary)
            }

            if usageService.hasAPIData && usageService.oauthUsage.isWeeklyNearLimit {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                    Text("Weekly limit \(Int(min(usageService.oauthUsage.sevenDay.utilization, 100)))%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .glassEffect(.regular.tint(.orange.opacity(0.1)), in: .capsule)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    // MARK: - Cost

    @ViewBuilder
    private var costSection: some View {
        let fiveHourCost = usageService.aggregatedUsage.fiveHourCost
        let dailyCost = usageService.aggregatedUsage.dailyCost

        VStack(spacing: 8) {
            HStack {
                Text("Estimated Cost")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.3)
                Spacer()
            }

            HStack(spacing: 0) {
                costColumn(
                    NumberFormatting.formatDollarCost(fiveHourCost.totalCost),
                    label: "5h window"
                )

                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 0.5, height: 26)

                costColumn(
                    NumberFormatting.formatDollarCost(dailyCost.totalCost),
                    label: "today"
                )
            }

            if fiveHourCost.totalCost > 0 {
                HStack(spacing: 8) {
                    costChip("In", fiveHourCost.inputCost, .blue)
                    costChip("Out", fiveHourCost.outputCost, .purple)
                    costChip("CW", fiveHourCost.cacheWriteCost, .orange)
                    costChip("CR", fiveHourCost.cacheReadCost, .green)
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    @ViewBuilder
    private func costColumn(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tokens

    @ViewBuilder
    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TokenBreakdownView(
                usage: usageService.aggregatedUsage.fiveHourWindow,
                title: "5-Hour Tokens"
            )
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    // MARK: - Rate Limits

    @ViewBuilder
    private var rateLimitSection: some View {
        let usage = usageService.oauthUsage
        HStack(spacing: 6) {
            ratePill("5h", Int(min(usage.fiveHour.utilization, 100)))
            ratePill("7d", Int(min(usage.sevenDay.utilization, 100)))
                .opacity(usage.isWeeklyNearLimit ? 1.0 : 0.4)
            if let sonnet = usage.sevenDaySonnet {
                ratePill("Sonnet", Int(min(sonnet.utilization, 100)))
                    .opacity(usage.isWeeklyNearLimit ? 1.0 : 0.4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func costChip(_ label: String, _ amount: Double, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 4, height: 4)
            Text("\(label) \(NumberFormatting.formatDollarCost(amount))")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.quaternary)
        }
    }

    @ViewBuilder
    private func ratePill(_ label: String, _ pct: Int) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
            Text("\(pct)%")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(pct >= 90 ? .red : pct >= 70 ? .orange : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
    }
}
