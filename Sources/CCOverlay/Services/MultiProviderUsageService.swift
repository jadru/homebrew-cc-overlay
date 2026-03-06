import Foundation
import Observation

@Observable
@MainActor
final class MultiProviderUsageService {
    private(set) var activeProviders: [CLIProvider] = []
    private(set) var isLoading = false

    private var services: [CLIProvider: any ProviderServiceProtocol] = [:]
    private var settings: AppSettings?
    private var usageHistoryService: UsageHistoryService?
    private var lastInterval: TimeInterval = AppConstants.defaultRefreshInterval

    init() {}

    /// Bind settings for reading provider enable/disable.
    func configure(settings: AppSettings, usageHistoryService: UsageHistoryService? = nil) {
        self.settings = settings
        if let usageHistoryService {
            self.usageHistoryService = usageHistoryService
        }
    }

    func isProviderPaused(_ provider: CLIProvider) -> Bool {
        settings?.isProviderPaused(provider) ?? false
    }

    func setProviderPaused(_ provider: CLIProvider, paused: Bool) {
        guard let settings else { return }
        settings.setProviderPaused(provider, paused: paused)

        if paused {
            if let service = services.removeValue(forKey: provider) {
                service.stopMonitoring()
            }
            activeProviders = currentActiveProviders
            return
        }

        Task {
            await resumeProvider(provider)
        }
    }

    // MARK: - Data Access

    func usageData(for provider: CLIProvider) -> ProviderUsageData {
        services[provider]?.usageData ?? .empty(for: provider)
    }

    /// The provider with the lowest remaining percentage (most critical).
    var criticalProvider: CLIProvider? {
        activeProviders
            .filter { usageData(for: $0).isAvailable }
            .min { usageData(for: $0).remainingPercentage < usageData(for: $1).remainingPercentage }
    }

    /// Cached snapshot of the last non-empty recently-active list.
    private var lastKnownActiveProviders: [CLIProvider] = []

    /// Providers with token consumption in the last 5 minutes, sorted by usedPercentage descending.
    /// When all providers are idle, returns the last known active state so the display is preserved.
    var recentlyActiveProviders: [CLIProvider] {
        let cutoff = Date().addingTimeInterval(-AppConstants.activityWindowSeconds)
        let current = activeProviders
            .filter {
                let data = usageData(for: $0)
                guard data.isAvailable, let at = data.lastActivityAt else { return false }
                return at > cutoff
            }
            .sorted { usageData(for: $0).usedPercentage > usageData(for: $1).usedPercentage }

        if !current.isEmpty {
            if current != lastKnownActiveProviders {
                lastKnownActiveProviders = current
            }
            return current
        }
        return lastKnownActiveProviders
    }

    // MARK: - Monitoring

    func startMonitoring(interval: TimeInterval = AppConstants.defaultRefreshInterval) {
        lastInterval = interval
        Task {
            await detectProviders()
            for service in services.values {
                service.startMonitoring(interval: interval)
            }
        }
    }

    func stopMonitoring() {
        for service in services.values {
            service.stopMonitoring()
        }
    }

    func refresh() {
        Task {
            await detectProviders(skipExisting: true)

            for service in services.values {
                service.refresh()
            }
        }
    }

    func updateRefreshInterval(_ interval: TimeInterval) {
        stopMonitoring()
        startMonitoring(interval: interval)
    }

    // MARK: - Detection

    private func detectProviders(skipExisting: Bool = false) async {
        let interval = lastInterval
        DebugFlowLogger.shared.log(
            stage: .detection,
            message: "scan.start",
            details: [
                "skipExisting": "\(skipExisting)",
                "interval": "\(interval)"
            ]
        )

        var changed = false
        var servicesMutated = false

        for providerType in CLIProvider.allCases {
            guard let settings else { continue }
            guard settings.isEnabled(providerType), !settings.isProviderPaused(providerType) else {
                if let service = services.removeValue(forKey: providerType) {
                    service.stopMonitoring()
                    servicesMutated = true
                }
                continue
            }
            if skipExisting && services[providerType] != nil {
                DebugFlowLogger.shared.log(
                    stage: .detection,
                    provider: providerType,
                    message: "detect.skip.existing"
                )
                continue
            }

            DebugFlowLogger.shared.log(
                stage: .detection,
                provider: providerType,
                message: "detect.start"
            )

            if let service = await createAndDetect(for: providerType) {
                services[providerType] = service
                if skipExisting {
                    service.startMonitoring(interval: interval)
                }
                changed = true
                DebugFlowLogger.shared.log(
                    stage: .detection,
                    provider: providerType,
                    message: "detect.success"
                )
            } else {
                DebugFlowLogger.shared.log(
                    stage: .detection,
                    provider: providerType,
                    message: "detect.fail"
                )
            }
        }

        let nextActiveProviders = CLIProvider.allCases.filter { services[$0] != nil }
        if nextActiveProviders != activeProviders {
            DebugFlowLogger.shared.log(
                stage: .display,
                message: "active-providers.changed",
                details: [
                    "from": activeProviders.map(\.rawValue).joined(separator: ","),
                    "to": nextActiveProviders.map(\.rawValue).joined(separator: ",")
                ]
            )
        }

        if changed || !skipExisting {
            activeProviders = nextActiveProviders
        } else if servicesMutated {
            activeProviders = nextActiveProviders
        }
    }

    private func createAndDetect(for provider: CLIProvider) async -> (any ProviderServiceProtocol)? {
        switch provider {
        case .claudeCode:
            let service = ClaudeCodeProviderService(usageHistoryService: usageHistoryService)
            return service.detect() ? service : nil
        case .codex:
            let service = CodexProviderService()
            return await service.detect() ? service : nil
        case .gemini:
            let service = GeminiProviderService()
            return await service.detect() ? service : nil
        }
    }

    private func resumeProvider(_ provider: CLIProvider) async {
        guard let settings else { return }
        guard settings.isEnabled(provider), !settings.isProviderPaused(provider) else { return }
        if services[provider] != nil {
            services[provider]?.startMonitoring(interval: lastInterval)
            activeProviders = currentActiveProviders
            return
        }

        guard let service = await createAndDetect(for: provider) else { return }
        services[provider] = service
        service.startMonitoring(interval: lastInterval)
        activeProviders = currentActiveProviders
    }

    private var currentActiveProviders: [CLIProvider] {
        CLIProvider.allCases.filter { services[$0] != nil }
    }

    // MARK: - Backward Compatibility Helpers

    /// Primary usage percentage (from the most critical provider, or Claude by default).
    var usedPercentage: Double {
        if let critical = criticalProvider {
            return usageData(for: critical).usedPercentage
        }
        return services[.claudeCode]?.usageData.usedPercentage ?? 0
    }

    var remainingPercentage: Double {
        100.0 - usedPercentage
    }

    /// Claude-specific: needed for CostAlertManager backward compat.
    var claudeOAuthUsage: ProviderUsageData {
        (services[.claudeCode] as? ClaudeCodeProviderService)?.usageData ?? .empty(for: .claudeCode)
    }

    var lastRefresh: Date? {
        activeProviders.compactMap { usageData(for: $0).lastRefresh }.max()
    }

    var staleThreshold: TimeInterval {
        let interval = settings?.refreshInterval ?? AppConstants.defaultRefreshInterval
        return max(interval * 2, AppConstants.defaultRefreshInterval)
    }

    func isStale(lastRefresh: Date?) -> Bool {
        guard let lastRefresh else { return false }
        return Date().timeIntervalSince(lastRefresh) > staleThreshold
    }

    var hasStaleData: Bool {
        isStale(lastRefresh: lastRefresh)
    }

    var error: String? {
        for provider in activeProviders {
            if let err = usageData(for: provider).error {
                return err
            }
        }
        return nil
    }
}
