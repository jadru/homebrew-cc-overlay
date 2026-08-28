import Foundation

/// Provider-usage values shared by the compact overlay and on-demand dashboard.
/// Keeping this presentation logic outside a SwiftUI view lets it be tested
/// without making the system monitor depend on a provider being available.
enum OverlayUsagePresentation {
    enum CompactValue: Equatable, Sendable {
        case remainingPercentage(Int)
        case tokenCount(Int)

        var displayText: String {
            switch self {
            case let .remainingPercentage(percentage): "\(percentage)%"
            case let .tokenCount(count): NumberFormatting.formatTokenCount(count)
            }
        }

        var accessibilityText: String {
            switch self {
            case let .remainingPercentage(percentage): "\(percentage) percent remaining"
            case let .tokenCount(count): "\(NumberFormatting.formatTokenCount(count)) tokens"
            }
        }
    }

    struct CompactProviderUsage: Identifiable, Equatable, Sendable {
        let provider: CLIProvider
        let value: CompactValue

        var id: CLIProvider { provider }
    }

    struct WindowBucket: Identifiable, Equatable, Sendable {
        let id: String
        let label: String
        let percentage: Int
        let utilization: Double
        let resetsAt: Date?
        let showWarning: Bool
    }

    static func windowBuckets(for data: ProviderUsageData) -> [WindowBucket] {
        guard data.isAvailable else { return [] }

        var seen = Set<String>()
        return data.rateLimitBuckets.compactMap { bucket in
            guard let label = normalizedWindowLabel(bucket.label), seen.insert(label).inserted else {
                return nil
            }

            let utilization = min(max(bucket.utilization, 0), 100)
            return WindowBucket(
                id: label,
                label: label,
                percentage: Int((100 - utilization).rounded()),
                utilization: utilization,
                resetsAt: bucket.resetsAt,
                showWarning: bucket.isWarning
            )
        }
    }

    static func visibleProviders(
        activeProviders: [CLIProvider],
        recentlyActiveProviders: [CLIProvider],
        usageData: (CLIProvider) -> ProviderUsageData
    ) -> [CLIProvider] {
        var seen = Set<CLIProvider>()
        return (recentlyActiveProviders + activeProviders).filter { provider in
            seen.insert(provider).inserted && usageData(provider).isAvailable
        }
    }

    static func compactProviders(
        activeProviders: [CLIProvider],
        usageData: (CLIProvider) -> ProviderUsageData
    ) -> [CompactProviderUsage] {
        CLIProvider.productOrder.compactMap { provider in
            guard activeProviders.contains(provider),
                  let value = compactValue(for: usageData(provider))
            else {
                return nil
            }
            return CompactProviderUsage(provider: provider, value: value)
        }
    }

    static func compactValue(for data: ProviderUsageData) -> CompactValue? {
        guard data.isAvailable else { return nil }

        if shouldShowTokenCount(for: data), let tokenCount = tokenCount(for: data), tokenCount > 0 {
            return .tokenCount(tokenCount)
        }
        return .remainingPercentage(Int(data.remainingPercentage.rounded()))
    }

    private static func shouldShowTokenCount(for data: ProviderUsageData) -> Bool {
        data.enterpriseQuota != nil
            || data.isEstimated
            || data.creditsInfo?.unlimited == true
    }

    private static func tokenCount(for data: ProviderUsageData) -> Int? {
        data.tokenCount ?? data.tokenBreakdown?.usage.rawTokens
    }

    private static func normalizedWindowLabel(_ label: String) -> String? {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "5h": "5H"
        case "1w", "7d": "7D"
        default: nil
        }
    }
}
