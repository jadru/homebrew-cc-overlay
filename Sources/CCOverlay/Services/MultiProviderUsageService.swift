import Foundation
import Observation

@Observable
@MainActor
final class MultiProviderUsageService {
    private(set) var activeProviders: [CLIProvider] = []
    private(set) var isLoading = false

    private var claudeService: ClaudeCodeProviderService?
    private var codexService: CodexProviderService?
    private var geminiService: GeminiProviderService?
    private var settings: AppSettings?

    init() {}

    /// Bind settings for reading provider enable/disable and Codex API key.
    func configure(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Data Access

    func usageData(for provider: CLIProvider) -> ProviderUsageData {
        switch provider {
        case .claudeCode:
            return claudeService?.usageData ?? .empty(for: .claudeCode)
        case .codex:
            return codexService?.usageData ?? .empty(for: .codex)
        case .gemini:
            return geminiService?.usageData ?? .empty(for: .gemini)
        }
    }

    /// The provider with the lowest remaining percentage (most critical).
    var criticalProvider: CLIProvider? {
        activeProviders
            .filter { usageData(for: $0).isAvailable }
            .min { usageData(for: $0).remainingPercentage < usageData(for: $1).remainingPercentage }
    }

    // MARK: - Monitoring

    func startMonitoring(interval: TimeInterval = AppConstants.defaultRefreshInterval) {
        Task {
            await detectProviders()
            for provider in activeProviders {
                switch provider {
                case .claudeCode:
                    claudeService?.startMonitoring(interval: interval)
                case .codex:
                    codexService?.startMonitoring(interval: interval)
                case .gemini:
                    geminiService?.startMonitoring(interval: interval)
                }
            }
        }
    }

    func stopMonitoring() {
        claudeService?.stopMonitoring()
        codexService?.stopMonitoring()
        geminiService?.stopMonitoring()
    }

    func refresh() {
        Task {
            // Re-detect providers that aren't active yet (e.g. newly installed)
            await detectNewProviders()

            for provider in activeProviders {
                switch provider {
                case .claudeCode:
                    claudeService?.refresh()
                case .codex:
                    codexService?.refresh()
                case .gemini:
                    geminiService?.refresh()
                }
            }
        }
    }

    func updateRefreshInterval(_ interval: TimeInterval) {
        stopMonitoring()
        startMonitoring(interval: interval)
    }

    // MARK: - Detection

    /// Check for newly available providers without disrupting existing ones.
    private func detectNewProviders() async {
        var changed = false

        if claudeService == nil && (settings?.claudeCodeEnabled ?? true) {
            let claude = ClaudeCodeProviderService()
            if claude.detect() {
                self.claudeService = claude
                claude.startMonitoring(interval: settings?.refreshInterval ?? AppConstants.defaultRefreshInterval)
                changed = true
            }
        }

        if codexService == nil && (settings?.codexEnabled ?? true) {
            let codex = CodexProviderService()
            if await codex.detect(manualAPIKey: settings?.codexAPIKey) {
                self.codexService = codex
                codex.startMonitoring(interval: settings?.refreshInterval ?? AppConstants.defaultRefreshInterval)
                changed = true
            }
        }

        if geminiService == nil && (settings?.geminiEnabled ?? true) {
            let gemini = GeminiProviderService()
            if await gemini.detect(manualAPIKey: settings?.geminiAPIKey) {
                self.geminiService = gemini
                gemini.startMonitoring(interval: settings?.refreshInterval ?? AppConstants.defaultRefreshInterval)
                changed = true
            }
        }

        if changed {
            var detected: [CLIProvider] = []
            if claudeService != nil { detected.append(.claudeCode) }
            if codexService != nil { detected.append(.codex) }
            if geminiService != nil { detected.append(.gemini) }
            self.activeProviders = detected
        }
    }

    private func detectProviders() async {
        var detected: [CLIProvider] = []

        // Detect Claude Code
        let claude = ClaudeCodeProviderService()
        if claude.detect() && (settings?.claudeCodeEnabled ?? true) {
            self.claudeService = claude
            detected.append(.claudeCode)
        }

        // Detect Codex
        let codex = CodexProviderService()
        let manualKey = settings?.codexAPIKey
        if await codex.detect(manualAPIKey: manualKey) && (settings?.codexEnabled ?? true) {
            self.codexService = codex
            detected.append(.codex)
        }

        // Detect Gemini
        let gemini = GeminiProviderService()
        let manualGeminiKey = settings?.geminiAPIKey
        if await gemini.detect(manualAPIKey: manualGeminiKey) && (settings?.geminiEnabled ?? true) {
            self.geminiService = gemini
            detected.append(.gemini)
        }

        self.activeProviders = detected
    }

    // MARK: - Backward Compatibility Helpers

    /// Primary usage percentage (from the most critical provider, or Claude by default).
    var usedPercentage: Double {
        if let critical = criticalProvider {
            return usageData(for: critical).usedPercentage
        }
        return claudeService?.usageData.usedPercentage ?? 0
    }

    var remainingPercentage: Double {
        100.0 - usedPercentage
    }

    /// Claude-specific: needed for CostAlertManager backward compat.
    var claudeOAuthUsage: OAuthUsageStatus {
        claudeService?.innerService.oauthUsage ?? .empty
    }

    var lastRefresh: Date? {
        activeProviders.compactMap { usageData(for: $0).lastRefresh }.max()
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
