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
    private var baseInterval: TimeInterval = AppConstants.defaultRefreshInterval
    private var currentInterval: TimeInterval = AppConstants.defaultRefreshInterval

    init(provider: CLIProvider) {
        self.provider = provider
    }

    // MARK: - Subclass Overrides

    /// Subclasses must override this method.
    func fetchUsage() async {
        fatalError("Subclass must override fetchUsage()")
    }

    /// Override in subclasses to build provider-specific usage data.
    var usageData: ProviderUsageData {
        .empty(for: provider, error: error, lastRefresh: lastRefresh, isLoading: isLoading)
    }

    // MARK: - Monitoring

    func startMonitoring(interval: TimeInterval = AppConstants.defaultRefreshInterval) {
        baseInterval = interval
        currentInterval = interval
        refresh()
        rescheduleTimer()
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
            adjustInterval()
        }
    }

    // MARK: - Polling Backoff

    private func adjustInterval() {
        let isActive: Bool
        if let activity = lastActivityAt {
            isActive = Date().timeIntervalSince(activity) < AppConstants.activityWindowSeconds
        } else {
            isActive = false
        }

        if isActive {
            currentInterval = baseInterval
        } else {
            let maxInterval = min(
                baseInterval * AppConstants.maxBackoffMultiplier,
                AppConstants.maxRefreshInterval
            )
            currentInterval = min(currentInterval * AppConstants.backoffMultiplier, maxInterval)
        }

        rescheduleTimer()
    }

    private func rescheduleTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    // MARK: - State Helpers

    /// Call from subclass after fetching new usage to track activity changes.
    func trackActivity(newUsedPct: Double) {
        if lastKnownUsedPct >= 0 && newUsedPct > lastKnownUsedPct {
            lastActivityAt = Date()
            // Snap back to base interval on activity
            if currentInterval > baseInterval {
                currentInterval = baseInterval
                rescheduleTimer()
            }
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
