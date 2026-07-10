import Foundation

/// Unified interface for all CLI provider services.
@MainActor
protocol ProviderServiceProtocol: AnyObject {
    var provider: CLIProvider { get }
    var isDetected: Bool { get }
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }
    var error: String? { get }
    var lastRefresh: Date? { get }
    var lastActivityAt: Date? { get }
    var usageData: ProviderUsageData { get }

    func fetchUsage() async
    func revalidate(settings: AppSettings?) async -> Bool
    func startMonitoring(interval: TimeInterval)
    func stopMonitoring()
    func refresh()
}
