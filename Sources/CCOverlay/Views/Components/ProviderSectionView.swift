import SwiftUI

/// A reusable section that displays a single provider's usage data.
/// Used in MenuBarView to render each detected provider.
struct ProviderSectionView: View {
    let data: ProviderUsageData
    let activeSessions: [ActiveSession]

    private var maxProjectRows: Int {
        switch data.provider {
        case .claudeCode, .codex:
            return 2
        case .gemini:
            return 3
        }
    }

    private var maxModelRows: Int {
        switch data.provider {
        case .codex:
            return 2
        case .claudeCode:
            return 4
        case .gemini:
            return 3
        }
    }

    private var maxRateWindowRows: Int {
        data.provider == .codex ? 3 : 4
    }

    var body: some View {
        VStack(spacing: 10) {
            gaugeCard
            enterpriseQuotaCard
            creditsInfoCard
            costCard
            modelBreakdownCard
            detailedRateWindowsCard
            projectCostCard
            usageTrendCard
            activeSessionCard
            tokenBreakdownCard
            healthCard
        }
    }

    // MARK: - Gauge

    @ViewBuilder
    private var gaugeCard: some View {
        if data.isAvailable {
            GaugeCardView(
                remainingPercentage: data.remainingPercentage,
                resetsAt: data.resetsAt,
                weeklyWarningPercentage: data.gaugeWarningPercentage,
                showLiveIndicator: true,
                rateLimitBuckets: data.gaugeRateLimitBuckets,
                predictionText: data.exhaustionPrediction?.formattedTimeRemaining,
                size: .standard,
                title: "\(data.primaryWindowLabel) Limit"
            )
        } else {
            providerSetupCard
        }
    }

    // MARK: - Enterprise Quota (Claude only)

    @ViewBuilder
    private var enterpriseQuotaCard: some View {
        if let quota = data.enterpriseQuota, quota.isAvailable {
            EnterpriseQuotaCardView(quota: quota, size: .standard)
        }
    }

    // MARK: - Credits Info (Codex only)

    @ViewBuilder
    private var creditsInfoCard: some View {
        if let credits = data.creditsInfo {
            CreditsInfoCardView(credits: credits, size: .standard)
        }
    }

    // MARK: - Detailed Rate Windows (Codex only)

    @ViewBuilder
    private var detailedRateWindowsCard: some View {
        if let windows = data.detailedRateWindows, !windows.isEmpty {
            RateWindowsCardView(
                windows: windows,
                maxVisibleRows: maxRateWindowRows,
                size: .standard
            )
        }
    }

    // MARK: - Cost

    @ViewBuilder
    private var costCard: some View {
        if let cost = data.estimatedCost {
            CostCardView(
                fiveHourCost: cost.breakdown ?? .zero,
                dailyCost: CostBreakdown(
                    inputCost: cost.dailyCost,
                    outputCost: 0,
                    cacheWriteCost: 0,
                    cacheReadCost: 0
                ),
                size: .standard,
                windowLabel: cost.windowLabel,
                dailyLabel: cost.dailyLabel
            )
        }
    }

    // MARK: - Models

    @ViewBuilder
    private var modelBreakdownCard: some View {
        if let models = data.modelBreakdowns, !models.isEmpty {
            ModelBreakdownCardView(
                models: models,
                maxVisibleRows: maxModelRows,
                size: .standard
            )
        }
    }

    // MARK: - Projects

    @ViewBuilder
    private var projectCostCard: some View {
        if let projects = data.projectCosts, !projects.isEmpty {
            ProjectCostCardView(
                projects: projects,
                maxVisibleRows: maxProjectRows,
                size: .standard
            )
        }
    }

    // MARK: - Usage Trend

    @ViewBuilder
    private var usageTrendCard: some View {
        if let points = data.sparklineData, points.count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(
                    title: "Usage Trend",
                    iconName: "chart.line.uptrend.xyaxis",
                    size: .standard
                )
                SparklineView(dataPoints: points)
                    .frame(height: 34)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(CardBackgroundModifier(useGlass: true, cornerRadius: 16))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Usage trend over the last 7 days, latest value \(points.last.map { NumberFormatting.formatDollarCost($0) } ?? "$0.00")"
            )
        }
    }

    // MARK: - Active Sessions

    @ViewBuilder
    private var activeSessionCard: some View {
        if data.provider == .claudeCode && !activeSessions.isEmpty {
            SessionCardView(sessions: activeSessions, size: .standard)
        }
    }

    // MARK: - Token Breakdown

    @ViewBuilder
    private var tokenBreakdownCard: some View {
        if let tokens = data.tokenBreakdown, tokens.usage.totalTokens > 0 {
            VStack(alignment: .leading, spacing: 6) {
                TokenBreakdownView(
                    usage: tokens.usage,
                    title: tokens.title
                )
            }
            .padding(14)
            .compatGlassRoundedRect(cornerRadius: 16)
        }
    }

    // MARK: - Provider Health

    @ViewBuilder
    private var healthCard: some View {
        ProviderHealthCardView(data: data, size: .standard)
    }

    // MARK: - Setup Card (shown when provider is not available)

    @ViewBuilder
    private var providerSetupCard: some View {
        VStack(spacing: 14) {
            Image(systemName: data.provider.iconName)
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Not set up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(data.provider.setupInstructions)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            if let error = data.error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 10))
                        .accessibilityHidden(true)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .compatGlassRoundedRect(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Provider not set up. \(data.provider.setupInstructions)")
    }

}
