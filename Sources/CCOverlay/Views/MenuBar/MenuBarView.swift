import AppKit
import SwiftUI

struct MenuBarView: View {
    let usageService: UsageDataService
    @Bindable var settings: AppSettings
    var onOpenSettings: (() -> Void)?

    @State private var showRefreshSuccess = false
    @State private var refreshRotation: Double = 0

    var body: some View {
        VStack(spacing: 14) {
            headerSection
            primaryGaugeCard
            enterpriseQuotaCard
            costCard
            tokenBreakdownCard
            controlsSection
            footerSection
        }
        .padding(16)
        .frame(width: 300)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Code")
                    .font(.system(size: 15, weight: .semibold))

                if let plan = usageService.detectedPlan {
                    Text(PlanTier.displayName(for: plan))
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
                    .foregroundStyle(showRefreshSuccess ? .green : .primary)
                    .rotationEffect(.degrees(refreshRotation))
            }
            .buttonStyle(.borderless)
            .disabled(usageService.isLoading)
            .focusable(false)
            .accessibilityHidden(true)
            .compatGlassCircle(interactive: true)
            .onChange(of: usageService.isLoading) { _, isLoading in
                if isLoading {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        refreshRotation = 360
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        refreshRotation = 0
                    }
                }
            }
            .onChange(of: usageService.lastRefresh) { _, newValue in
                guard newValue != nil, usageService.error == nil else { return }
                withAnimation(.easeIn(duration: 0.15)) {
                    showRefreshSuccess = true
                }
                withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
                    showRefreshSuccess = false
                }
            }
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
        let remainPct = 100.0 - usage.usedPercentage

        GaugeCardView(
            remainingPercentage: remainPct,
            resetsAt: usage.primaryResetsAt,
            weeklyWarningPercentage: usage.isWeeklyNearLimit ? Int(min(usage.sevenDay.utilization, 100)) : nil,
            showLiveIndicator: true,
            rateLimitBuckets: makeRateLimitBuckets(from: usage),
            size: .standard
        )
    }

    @ViewBuilder
    private var localGaugeCard: some View {
        let usedPct = usageService.aggregatedUsage.usagePercentage(limit: settings.weightedCostLimit)
        let remainPct = 100.0 - usedPct

        GaugeCardView(
            remainingPercentage: remainPct,
            size: .standard,
            title: "5-Hour Window (estimated)"
        )
    }

    private func makeRateLimitBuckets(from usage: OAuthUsageStatus) -> [GaugeCardView.RateLimitBucket] {
        var buckets: [GaugeCardView.RateLimitBucket] = [
            .init(label: "5h", percentage: 100 - Int(min(usage.fiveHour.utilization, 100))),
            .init(label: "7d", percentage: 100 - Int(min(usage.sevenDay.utilization, 100)), dimmed: !usage.isWeeklyNearLimit)
        ]
        if let sonnet = usage.sevenDaySonnet {
            buckets.append(.init(label: "Sonnet", percentage: 100 - Int(min(sonnet.utilization, 100)), dimmed: !usage.isWeeklyNearLimit))
        }
        return buckets
    }

    // MARK: - Enterprise Quota

    @ViewBuilder
    private var enterpriseQuotaCard: some View {
        if let quota = usageService.oauthUsage.enterpriseQuota, quota.isAvailable {
            EnterpriseQuotaCardView(quota: quota, size: .standard)
        }
    }

    // MARK: - Cost Card

    @ViewBuilder
    private var costCard: some View {
        CostCardView(
            fiveHourCost: usageService.aggregatedUsage.fiveHourCost,
            dailyCost: usageService.aggregatedUsage.dailyCost,
            size: .standard
        )
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
        .compatGlassRoundedRect(cornerRadius: 16)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsSection: some View {
        HStack {
            Spacer()

            Button {
                onOpenSettings?()
            } label: {
                Label("Settings", systemImage: "gear")
                    .font(.system(size: 11))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderless)
            .compatGlassCapsule(interactive: true)
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
                ErrorBannerView(
                    error: AppError.from(error),
                    onRetry: { usageService.refresh() },
                    compact: true
                )
            }
        }
    }

}
