import Foundation
import SwiftUI

/// ViewModel for MenuBarView that handles derived state computation.
@Observable
@MainActor
final class MenuBarViewModel {
    private let usageService: UsageDataService
    private let settings: AppSettings

    init(usageService: UsageDataService, settings: AppSettings) {
        self.usageService = usageService
        self.settings = settings
    }

    // MARK: - Header Section

    var planDisplayName: String {
        if let plan = usageService.detectedPlan {
            return formatPlanName(plan)
        }
        return settings.planTier.rawValue
    }

    var isLoading: Bool {
        usageService.isLoading
    }

    var lastRefresh: Date? {
        usageService.lastRefresh
    }

    var error: String? {
        usageService.error
    }

    var appError: AppError? {
        guard let errorMessage = error else { return nil }
        return AppError.from(errorMessage)
    }

    // MARK: - Gauge Section

    var hasAPIData: Bool {
        usageService.hasAPIData
    }

    var remainingPercentage: Double {
        if hasAPIData {
            return usageService.remainingPercentage
        }
        return 100.0 - usageService.aggregatedUsage.usagePercentage(limit: settings.weightedCostLimit)
    }

    var tintColor: Color {
        Color.usageTint(for: remainingPercentage)
    }

    var resetsAt: Date? {
        guard hasAPIData else { return nil }
        return usageService.oauthUsage.primaryResetsAt
    }

    var weeklyWarningPercentage: Int? {
        guard hasAPIData, usageService.oauthUsage.isWeeklyNearLimit else { return nil }
        return Int(min(usageService.oauthUsage.sevenDay.utilization, 100))
    }

    var gaugeTitle: String {
        hasAPIData ? "Session Limit" : "5-Hour Window (estimated)"
    }

    var rateLimitBuckets: [GaugeCardView.RateLimitBucket] {
        guard hasAPIData else { return [] }
        let usage = usageService.oauthUsage

        var buckets: [GaugeCardView.RateLimitBucket] = [
            .init(label: "5h", percentage: Int(min(usage.fiveHour.utilization, 100))),
            .init(label: "7d", percentage: Int(min(usage.sevenDay.utilization, 100)), dimmed: !usage.isWeeklyNearLimit)
        ]

        if let sonnet = usage.sevenDaySonnet {
            buckets.append(.init(label: "Sonnet", percentage: Int(min(sonnet.utilization, 100)), dimmed: !usage.isWeeklyNearLimit))
        }

        return buckets
    }

    // MARK: - Cost Section

    var fiveHourCost: CostBreakdown {
        usageService.aggregatedUsage.fiveHourCost
    }

    var dailyCost: CostBreakdown {
        usageService.aggregatedUsage.dailyCost
    }

    // MARK: - Token Section

    var fiveHourTokenUsage: TokenUsage {
        usageService.aggregatedUsage.fiveHourWindow
    }

    // MARK: - Controls

    var showOverlay: Bool {
        get { settings.showOverlay }
        set { settings.showOverlay = newValue }
    }

    // MARK: - Actions

    func refresh() {
        usageService.refresh()
    }

    // MARK: - Helpers

    private func formatPlanName(_ type: String) -> String {
        switch type {
        case "max_5": return "Max ($100/mo)"
        case "max_20": return "Max ($200/mo)"
        case "pro": return "Pro ($20/mo)"
        default: return type
        }
    }
}
