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
            VStack(spacing: 12) {
                gaugeSection
                costSection
                tokenSection
                if usageService.hasAPIData {
                    rateLimitSection
                }
            }
            .padding(14)
        }
    }

    // MARK: - Gauge

    @ViewBuilder
    private var gaugeSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: remainPct / 100)
                    .stroke(tintColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: remainPct)

                VStack(spacing: 2) {
                    Text(NumberFormatting.formatPercentage(remainPct))
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    Text("remaining")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 72, height: 72)

            if let resetsAt = usageService.oauthUsage.primaryResetsAt, resetsAt > Date() {
                Label {
                    Text("Resets \(resetsAt, style: .relative)")
                        .font(.system(size: 10))
                } icon: {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(NumberFormatting.formatDollarCost(fiveHourCost.totalCost))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("5h window")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 1, height: 28)

                VStack(spacing: 2) {
                    Text(NumberFormatting.formatDollarCost(dailyCost.totalCost))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("today")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }

            if fiveHourCost.totalCost > 0 {
                HStack(spacing: 10) {
                    costChip("In", fiveHourCost.inputCost, .blue)
                    costChip("Out", fiveHourCost.outputCost, .purple)
                    costChip("CW", fiveHourCost.cacheWriteCost, .orange)
                    costChip("CR", fiveHourCost.cacheReadCost, .green)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
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
        HStack(spacing: 8) {
            ratePill("5h", Int(min(usage.fiveHour.utilization, 100)))
            ratePill("7d", Int(min(usage.sevenDay.utilization, 100)))
                .opacity(usage.isWeeklyNearLimit ? 1.0 : 0.5)
            if let sonnet = usage.sevenDaySonnet {
                ratePill("Sonnet", Int(min(sonnet.utilization, 100)))
                    .opacity(usage.isWeeklyNearLimit ? 1.0 : 0.5)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func costChip(_ label: String, _ amount: Double, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(label) \(NumberFormatting.formatDollarCost(amount))")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
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
