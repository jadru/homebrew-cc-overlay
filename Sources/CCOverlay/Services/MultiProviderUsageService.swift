import Foundation
import Observation

@Observable
@MainActor
final class MultiProviderUsageService {
    typealias ProviderServiceFactory = @MainActor (CLIProvider, AppSettings?) async -> (any ProviderServiceProtocol)?

    private(set) var activeProviders: [CLIProvider] = []
    private(set) var isDetectingProviders = false
    var isLoading: Bool {
        isDetectingProviders || services.values.contains { $0.isLoading }
    }

    private var services: [CLIProvider: any ProviderServiceProtocol] = [:]
    private var settings: AppSettings?
    private var detectionTask: Task<Void, Never>?
    private let serviceFactory: ProviderServiceFactory?
    private var isMonitoring = false
    private var monitoringInterval = AppConstants.defaultRefreshInterval
    private var monitoredProviders = Set<CLIProvider>()
    private var detectionGeneration = 0
    @ObservationIgnored
    private let decisionHistory: DecisionHistoryStore
    @ObservationIgnored
    private let decisionStabilizer = UsageDecisionStabilizer()

    init(
        serviceFactory: ProviderServiceFactory? = nil,
        decisionHistory: DecisionHistoryStore? = nil
    ) {
        self.serviceFactory = serviceFactory
        self.decisionHistory = decisionHistory ?? DecisionHistoryStore()
    }

    /// Bind settings for reading provider enable/disable and API keys.
    func configure(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Data Access

    func usageData(for provider: CLIProvider) -> ProviderUsageData {
        services[provider]?.usageData ?? .empty(for: provider)
    }

    func usageExportEntries(for provider: CLIProvider) -> [ParsedUsageEntry] {
        services[provider]?.usageExportEntries ?? []
    }

    /// Providers with usage data ready for display.
    var availableProviders: [CLIProvider] {
        let available = activeProviders.filter { usageData(for: $0).isAvailable }
        guard settings?.providerPriority == .mostHeadroom else {
            return CLIProvider.productOrder.filter(available.contains)
        }
        return available.sorted {
            UsageDecisionEngine.headroom(for: usageData(for: $0))
                > UsageDecisionEngine.headroom(for: usageData(for: $1))
        }
    }

    /// The provider with the lowest remaining percentage (most critical).
    var criticalProvider: CLIProvider? {
        activeProviders
            .filter { usageData(for: $0).isAvailable }
            .min { usageData(for: $0).remainingPercentage < usageData(for: $1).remainingPercentage }
    }

    /// Global Run / Wait / Switch recommendation across every usable provider.
    var usageDecision: UsageDecision {
        let candidate = UsageDecisionEngine.recommend(
            from: activeProviders.map { usageData(for: $0) },
            currentProvider: recentlyActiveProviders.first,
            providerPriority: settings?.providerPriority ?? .codexFirst,
            fullResetPolicy: settings?.fullResetPolicy ?? .balanced,
            staleAfter: staleThreshold
        )
        return decisionStabilizer.resolve(candidate: candidate, snapshotVersion: lastRefresh)
    }

    func recordCurrentSamples(now: Date = Date()) {
        for provider in activeProviders {
            decisionHistory.record(usageData(for: provider), now: now)
        }
    }

    func recordDecisionFeedback(helpful: Bool, decision: UsageDecision) {
        decisionHistory.recordFeedback(helpful: helpful, decision: decision)
    }

    func updateFullResetPolicy(_ policy: FullResetPolicy) {
        settings?.fullResetPolicy = policy
        decisionStabilizer.reset()
    }

    func updateProviderPriority(_ priority: ProviderPriority) {
        settings?.providerPriority = priority
        decisionStabilizer.reset()
    }

    var decisionFeedbackSummary: DecisionHistoryStore.FeedbackSummary {
        decisionHistory.feedbackSummary
    }

    func usageHistory(for provider: CLIProvider, days: Int = 7) -> [UsageHistoryPoint] {
        decisionHistory.history(for: provider, days: days)
    }

    func headroomForecast(for provider: CLIProvider) -> ProviderHeadroomForecast {
        decisionHistory.forecast(for: usageData(for: provider))
    }

    func activationStatus(for provider: CLIProvider) -> ProviderActivationStatus {
        let data = usageData(for: provider)
        let binaryPath = provider == .codex
            ? CodexDetector.findBinary()
            : CLIBinaryFinder.find("claude")
        return ActivationDoctor.assess(
            provider: provider,
            data: data,
            isActive: activeProviders.contains(provider),
            isChecking: isDetectingProviders || data.isLoading,
            isStale: isStale(lastRefresh: data.lastRefresh),
            binaryPath: binaryPath
        )
    }

    func providerHealth(for provider: CLIProvider) -> ProviderHealthSnapshot {
        let service = services[provider]
        return ProviderHealthSnapshot(
            provider: provider,
            activation: activationStatus(for: provider),
            lastSuccess: service?.lastRefresh,
            responseTime: service?.lastRefreshDuration,
            consecutiveFailures: service?.consecutiveNetworkFailures ?? 0
        )
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
        detectionTask?.cancel()
        isMonitoring = true
        monitoringInterval = interval
        let generation = beginProviderDetection()
        detectionTask = Task {
            defer { finishProviderDetection(generation) }
            await detectProviders()
            guard !Task.isCancelled else { return }
            startServicesIfNeeded()
        }
    }

    func stopMonitoring() {
        detectionTask?.cancel()
        detectionTask = nil
        isMonitoring = false
        detectionGeneration += 1
        isDetectingProviders = false
        monitoredProviders.removeAll()
        for service in services.values {
            service.stopMonitoring()
        }
    }

    func refresh() {
        guard !isLoading else { return }

        let generation = beginProviderDetection()
        detectionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishProviderDetection(generation) }
            await detectProviders()
            guard !Task.isCancelled else { return }
            startServicesIfNeeded()

            for service in services.values {
                if let baseService = service as? BaseProviderService {
                    baseService.refresh(forceNetwork: true)
                } else {
                    service.refresh()
                }
            }
        }
    }

    private func beginProviderDetection() -> Int {
        detectionGeneration += 1
        isDetectingProviders = true
        return detectionGeneration
    }

    private func finishProviderDetection(_ generation: Int) {
        guard detectionGeneration == generation else { return }
        isDetectingProviders = false
    }

    func updateRefreshInterval(_ interval: TimeInterval) {
        stopMonitoring()
        startMonitoring(interval: interval)
    }

    // MARK: - Detection

    private func detectProviders() async {
        let interval = settings?.refreshInterval ?? AppConstants.defaultRefreshInterval
        DebugFlowLogger.shared.log(
            stage: .detection,
            message: "scan.start",
            details: [
                "interval": "\(interval)"
            ]
        )

        for providerType in CLIProvider.allCases {
            if let existing = services[providerType] {
                let isStillAvailable = await existing.revalidate(settings: settings)
                if isStillAvailable {
                    DebugFlowLogger.shared.log(
                        stage: .detection,
                        provider: providerType,
                        message: "detect.retained"
                    )
                    continue
                }

                existing.stopMonitoring()
                services.removeValue(forKey: providerType)
                monitoredProviders.remove(providerType)
                DebugFlowLogger.shared.log(
                    stage: .detection,
                    provider: providerType,
                    message: "detect.removed"
                )
            }

            DebugFlowLogger.shared.log(
                stage: .detection,
                provider: providerType,
                message: "detect.start"
            )

            if let service = await createAndDetect(for: providerType) {
                services[providerType] = service
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

        activeProviders = nextActiveProviders
    }

    private func createAndDetect(for provider: CLIProvider) async -> (any ProviderServiceProtocol)? {
        if let serviceFactory {
            return await serviceFactory(provider, settings)
        }
        return await Self.defaultServiceFactory(
            for: provider,
            settings: settings
        )
    }

    private func startServicesIfNeeded() {
        guard isMonitoring else { return }
        for provider in activeProviders {
            guard let service = services[provider], monitoredProviders.insert(provider).inserted else { continue }
            service.startMonitoring(interval: monitoringInterval)
        }
    }

    private static func defaultServiceFactory(
        for provider: CLIProvider,
        settings: AppSettings?
    ) async -> (any ProviderServiceProtocol)? {
        switch provider {
        case .claudeCode:
            let service = ClaudeCodeProviderService {
                settings?.weightedCostLimit ?? PlanTier.pro.weightedCostLimit
            } oauthAccessEnabled: {
                settings?.claudeOAuthEnabled ?? false
            }
            return service.detect() ? service : nil
        case .codex:
            let service = CodexProviderService()
            return await service.revalidate(settings: settings) ? service : nil
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

    /// Claude-specific: needed for CapacityAlertManager backward compat.
    var claudeOAuthUsage: ProviderUsageData {
        (services[.claudeCode] as? ClaudeCodeProviderService)?.usageData ?? .empty(for: .claudeCode)
    }

    var lastRefresh: Date? {
        activeProviders.compactMap { usageData(for: $0).lastRefresh }.max()
    }

    var staleThreshold: TimeInterval {
        let interval = settings?.refreshInterval ?? AppConstants.defaultRefreshInterval
        return max(interval * 2, interval + AppConstants.oauthTimeoutInterval)
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
