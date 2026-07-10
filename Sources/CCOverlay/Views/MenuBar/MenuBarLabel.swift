import SwiftUI

struct MenuBarLabel: View {
    let multiService: MultiProviderUsageService
    let updateService: UpdateService

    private var visibleProviders: [CLIProvider] {
        Self.visibleProviders(
            from: multiService.activeProviders,
            usageData: multiService.usageData(for:)
        )
    }

    private var criticalData: ProviderUsageData? {
        visibleProviders
            .map { multiService.usageData(for: $0) }
            .min { $0.remainingPercentage < $1.remainingPercentage }
    }

    private var isWeeklyWarning: Bool {
        criticalData?.rateLimitBuckets.contains(where: \.isWarning) ?? false
    }

    private var isStale: Bool {
        guard let data = criticalData else { return false }
        return multiService.isStale(lastRefresh: data.lastRefresh)
    }

    var body: some View {
        HStack(spacing: 6) {
            if visibleProviders.isEmpty {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 12, weight: .medium))
                    .accessibilityHidden(true)
                Text("--")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            } else {
                ForEach(visibleProviders, id: \.self) { provider in
                    providerStatus(for: provider)
                }
            }

            if isWeeklyWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.primary.opacity(0.9))
                    .accessibilityHidden(true)
            }

            if isStale {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 9))
                    .foregroundStyle(.primary.opacity(0.72))
                    .accessibilityHidden(true)
            }

            if case .updateAvailable = updateService.updateState {
                Circle()
                    .fill(.primary.opacity(0.88))
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
        }
        .animation(DesignTokens.Animation.press, value: isWeeklyWarning)
        .animation(DesignTokens.Animation.press, value: isStale)
        .padding(.horizontal, 3)
        .frame(height: 16)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usage status")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard let data = criticalData else {
            return "No provider usage data available"
        }

        var value = "\(data.provider.rawValue), \(Int(data.remainingPercentage)) percent remaining"
        if data.isEstimated {
            value += ", local estimate"
        }
        if isWeeklyWarning {
            value += ", warning threshold reached"
        }
        if isStale {
            value += ", data may be stale"
        }
        return value
    }

    private func providerStatus(for provider: CLIProvider) -> some View {
        let data = multiService.usageData(for: provider)

        return HStack(spacing: 3) {
            MenuBarUsageMark(provider: provider, remainingPercentage: data.remainingPercentage)
            Text("\(data.isEstimated ? "~" : "")\(NumberFormatting.formatPercentage(data.remainingPercentage))")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .accessibilityHidden(true)
    }

    static func visibleProviders(
        from providers: [CLIProvider],
        usageData: (CLIProvider) -> ProviderUsageData
    ) -> [CLIProvider] {
        providers.filter { usageData($0).isAvailable }
    }
}

private struct MenuBarUsageMark: View {
    let provider: CLIProvider
    let remainingPercentage: Double

    private var normalizedRemaining: Double {
        min(max(remainingPercentage / 100, 0), 1)
    }

    private var providerSymbol: String {
        switch provider {
        case .claudeCode:
            "sparkle"
        case .codex:
            "terminal.fill"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.22), lineWidth: 1.5)

            Circle()
                .trim(from: 0.06, to: max(0.08, 0.06 + normalizedRemaining * 0.88))
                .stroke(.primary, style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Image(systemName: providerSymbol)
                .font(.system(size: 6.5, weight: .bold))
        }
        .frame(width: 13, height: 13)
        .accessibilityHidden(true)
    }
}
