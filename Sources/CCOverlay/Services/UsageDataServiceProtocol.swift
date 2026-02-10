import Foundation

/// Protocol defining the interface for usage data services.
/// Enables dependency injection and testing with mock implementations.
@MainActor
protocol UsageDataServiceProtocol: AnyObject {
    var aggregatedUsage: AggregatedUsage { get }
    var oauthUsage: OAuthUsageStatus { get }
    var detectedPlan: String? { get }
    var isLoading: Bool { get }
    var lastRefresh: Date? { get }
    var error: String? { get }
    var usedPercentage: Double { get }
    var remainingPercentage: Double { get }
    var hasAPIData: Bool { get }
    var enterpriseQuota: EnterpriseQuota? { get }
    var isEnterprisePlan: Bool { get }

    func startMonitoring(interval: TimeInterval)
    func stopMonitoring()
    func updateRefreshInterval(_ interval: TimeInterval)
    func refresh()
}

// Conform the existing service to the protocol
extension UsageDataService: UsageDataServiceProtocol {}
