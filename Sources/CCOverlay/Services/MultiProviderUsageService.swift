import Foundation
import Observation

@Observable
@MainActor
final class MultiProviderUsageService {
    private(set) var activeProviders: [CLIProvider] = []
    private(set) var isLoading = false

    private var services: [CLIProvider: any ProviderServiceProtocol] = [:]
    private var settings: AppSettings?

    init() {}

    /// Bind settings for reading provider enable/disable and API keys.
    func configure(settings: AppSettings) {
        self.settings = settings
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
        let interval = settings?.refreshInterval ?? AppConstants.defaultRefreshInterval
        var changed = false

        for providerType in CLIProvider.allCases {
            guard isProviderEnabled(providerType) else { continue }
            if skipExisting && services[providerType] != nil { continue }

            if let service = await createAndDetect(for: providerType) {
                services[providerType] = service
                if skipExisting {
                    service.startMonitoring(interval: interval)
                }
                changed = true
            }
        }

        if changed || !skipExisting {
            activeProviders = CLIProvider.allCases.filter { services[$0] != nil }
        }
    }

    private func isProviderEnabled(_ provider: CLIProvider) -> Bool {
        guard let settings else { return true }
        switch provider {
        case .claudeCode: return settings.claudeCodeEnabled
        case .codex: return settings.codexEnabled
        case .gemini: return settings.geminiEnabled
        }
    }

    private func createAndDetect(for provider: CLIProvider) async -> (any ProviderServiceProtocol)? {
        switch provider {
        case .claudeCode:
            let service = ClaudeCodeProviderService()
            return service.detect() ? service : nil
        case .codex:
            let service = CodexProviderService()
            return await service.detect(manualAPIKey: settings?.codexAPIKey) ? service : nil
        case .gemini:
            let service = GeminiProviderService()
            return await service.detect(manualAPIKey: settings?.geminiAPIKey) ? service : nil
        }
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
    var claudeOAuthUsage: OAuthUsageStatus {
        (services[.claudeCode] as? ClaudeCodeProviderService)?.innerService.oauthUsage ?? .empty
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
