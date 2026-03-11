import SwiftUI

/// A reusable section that displays a single provider's usage data.
/// Used in MenuBarView to render each detected provider.
struct ProviderSectionView: View {
    let data: ProviderUsageData
    let allProviderData: [(CLIProvider, ProviderUsageData)]
    @Binding var selectedProvider: CLIProvider?
    let activeProviders: Set<CLIProvider>
    let settings: AppSettings

    var body: some View {
        VStack(spacing: 12) {
            ProviderSummaryCardView(
                allProviderData: allProviderData,
                selectedProvider: $selectedProvider,
                activeProviders: activeProviders
            )
            gaugeCard
            sessionDetailsCard
            enterpriseQuotaCard
            creditsInfoCard
            costCard
            detailedRateWindowsCard
            tokenBreakdownCard
        }
        .id(data.provider)
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        )
    }

    @ViewBuilder
    private var gaugeCard: some View {
        if data.isAvailable {
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

            GaugeCardView(
                remainingPercentage: data.remainingPercentage,
                resetsAt: data.resetsAt,
                weeklyWarningPercentage: weeklyWarning,
                showLiveIndicator: true,
                rateLimitBuckets: buckets,
                predictionText: data.provider == .claudeCode ? nil : data.exhaustionPrediction?.formattedTimeRemaining,
                size: .standard,
                title: data.provider == .claudeCode ? "Session Left" : "\(data.primaryWindowLabel) Left"
            )
        } else {
            providerSetupCard
        }
    }

    // MARK: - Enterprise Quota (Claude only)

    @ViewBuilder
    private var sessionDetailsCard: some View {
        ProviderSessionDetailsView(data: data, size: .standard)
    }

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
            .cardBackground(useGlass: true, cornerRadius: 16)
        }
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
        .cardBackground(useGlass: true, cornerRadius: 16)
    }

}
