import SwiftUI

/// A reusable section that displays a single provider's usage data.
/// Used in MenuBarView to render each detected provider.
struct ProviderSectionView: View {
    let data: ProviderUsageData
    let settings: AppSettings

    var body: some View {
        VStack(spacing: 10) {
            providerHeader
            gaugeCard
            enterpriseQuotaCard
            creditsInfoCard
            costCard
            detailedRateWindowsCard
            tokenBreakdownCard
        }
    }

    // MARK: - Header (icon removed – shown in sidebar)

    @ViewBuilder
    private var providerHeader: some View {
        EmptyView()
    }

    // MARK: - Gauge

    @ViewBuilder
    private var gaugeCard: some View {
        if data.isAvailable {
            let buckets: [GaugeCardView.RateLimitBucket] = data.rateLimitBuckets.map { b in
                .init(
                    label: b.label,
                    percentage: 100 - Int(min(b.utilization, 100)),
                    showWarning: b.isWarning,
                    dimmed: !b.isWarning
                )
            }

            let weeklyWarning: Int? = {
                if let weekly = data.rateLimitBuckets.first(where: { $0.isWarning }) {
                    return Int(min(weekly.utilization, 100))
                }
                return nil
            }()

            GaugeCardView(
                remainingPercentage: data.remainingPercentage,
                resetsAt: data.resetsAt,
                weeklyWarningPercentage: weeklyWarning,
                showLiveIndicator: true,
                rateLimitBuckets: buckets,
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
            RateWindowsCardView(windows: windows, size: .standard)
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

    // MARK: - Setup Card (shown when provider is not available)

    @ViewBuilder
    private var providerSetupCard: some View {
        VStack(spacing: 14) {
            Image(systemName: data.provider.iconName)
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("Not set up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(setupInstructions(for: data.provider))
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
    }

    private func setupInstructions(for provider: CLIProvider) -> String {
        switch provider {
        case .claudeCode:
            return "Install Claude Code and sign in\nnpm i -g @anthropic-ai/claude-code"
        case .codex:
            return "Install Codex CLI and authenticate\nnpm i -g @openai/codex && codex --login"
        case .gemini:
            return "Install Gemini CLI and authenticate\nnpm i -g @google/gemini-cli"
        }
    }
}
