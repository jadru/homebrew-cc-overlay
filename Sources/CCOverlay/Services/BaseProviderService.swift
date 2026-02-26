import Foundation
import Observation

/// Base class for CLI provider services that share timer-based monitoring,
/// task tracking, and activity detection logic.
@Observable
@MainActor
class BaseProviderService: ProviderServiceProtocol {
    let provider: CLIProvider

    private(set) var isDetected = false
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var lastRefresh: Date?
    private(set) var lastActivityAt: Date?

    private var lastKnownUsedPct: Double = -1
    private var refreshTimer: Timer?
    private var refreshTask: Task<Void, Never>?

    init(provider: CLIProvider) {
        self.provider = provider
    }

    // MARK: - Subclass Overrides

    /// Subclasses should override this method.
    func fetchUsage() async {
        assertionFailure("Subclass should override fetchUsage()")
    }

    /// Override in subclasses to build provider-specific usage data.
    var usageData: ProviderUsageData {
        .empty(for: provider, error: error, lastRefresh: lastRefresh, isLoading: isLoading)
    }

    // MARK: - Monitoring

    func startMonitoring(interval: TimeInterval = AppConstants.defaultRefreshInterval) {
        refresh()

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() {
        isLoading = true
        refreshTask?.cancel()
        refreshTask = Task {
            await fetchUsage()
            isLoading = false
        }
    }

    // MARK: - State Helpers

    /// Call from subclass after fetching new usage to track activity changes.
    func trackActivity(newUsedPct: Double) {
        if lastKnownUsedPct >= 0 && newUsedPct > lastKnownUsedPct {
            lastActivityAt = Date()
        }
        lastKnownUsedPct = newUsedPct
    }

    func markRefreshed() {
        lastRefresh = Date()
        error = nil
    }

    func setError(_ message: String?) {
        error = message
    }

    func setDetected(_ detected: Bool) {
        isDetected = detected
    }

    func setAuthenticated(_ authenticated: Bool) {
        isAuthenticated = authenticated
    }
}
