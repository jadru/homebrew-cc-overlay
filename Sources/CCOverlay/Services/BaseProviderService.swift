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
    private var refreshInterval: TimeInterval = AppConstants.defaultRefreshInterval
    private var consecutiveNetworkFailures = 0
    private var nextNetworkAttemptAt: Date?
    private var lastNetworkRequestAt: Date?
    private var forceNextNetworkRefresh = false

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
        refreshInterval = interval
        refresh()
        rescheduleTimer()
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        refreshTask?.cancel()
        refreshTask = nil
        isLoading = false
    }

    func refresh() {
        refresh(forceNetwork: false)
    }

    func refresh(forceNetwork: Bool) {
        guard !isLoading else { return }

        forceNextNetworkRefresh = forceNextNetworkRefresh || forceNetwork
        isLoading = true
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await fetchUsage()
            guard !Task.isCancelled else { return }
            isLoading = false
            refreshTask = nil
        }
    }

    func revalidate(settings: AppSettings?) async -> Bool {
        isDetected && isAuthenticated
    }

    private func rescheduleTimer() {
        refreshTimer?.invalidate()
        let timer = Timer(timeInterval: refreshInterval, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
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
        consecutiveNetworkFailures = 0
        nextNetworkAttemptAt = nil
    }

    /// Local-only data is still useful when the provider is intentionally unauthenticated.
    /// It does not reset a remote backoff window.
    func markLocalRefreshed(clearingError: Bool = false) {
        lastRefresh = Date()
        if clearingError {
            error = nil
        }
    }

    func canAttemptNetworkRefresh(at now: Date = Date()) -> Bool {
        let isForced = forceNextNetworkRefresh
        forceNextNetworkRefresh = false

        if let nextNetworkAttemptAt, now < nextNetworkAttemptAt {
            return false
        }

        if isForced {
            lastNetworkRequestAt = now
            return true
        }

        let isRecentlyActive = lastActivityAt.map {
            now.timeIntervalSince($0) <= AppConstants.activityWindowSeconds
        } ?? false
        let minimumInterval = isRecentlyActive
            ? refreshInterval
            : max(refreshInterval, AppConstants.idleNetworkRefreshInterval)

        guard let lastNetworkRequestAt,
              now.timeIntervalSince(lastNetworkRequestAt) < minimumInterval
        else {
            self.lastNetworkRequestAt = now
            return true
        }

        return false
    }

    @discardableResult
    func recordNetworkFailure(retryAfter: TimeInterval? = nil, now: Date = Date()) -> Date {
        consecutiveNetworkFailures += 1

        let baseDelay = max(refreshInterval, AppConstants.minimumNetworkRetryInterval)
        let multiplier = pow(2, Double(min(consecutiveNetworkFailures - 1, 4)))
        let exponentialDelay = min(baseDelay * multiplier, AppConstants.maximumNetworkRetryInterval)
        let delay = max(exponentialDelay, retryAfter ?? 0)
        let nextAttempt = now.addingTimeInterval(delay)
        nextNetworkAttemptAt = nextAttempt
        return nextAttempt
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
