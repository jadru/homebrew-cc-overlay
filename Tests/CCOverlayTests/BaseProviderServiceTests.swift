import XCTest
@testable import CCOverlay

@MainActor
private final class CountingProviderService: BaseProviderService {
    private(set) var fetchCount = 0

    init() {
        super.init(provider: .codex)
    }

    override func fetchUsage() async {
        fetchCount += 1
        markRefreshed()
    }
}

final class BaseProviderServiceTests: XCTestCase {
    @MainActor
    func testMonitoringRefreshesImmediately() async {
        let service = CountingProviderService()
        service.startMonitoring(interval: 0.08)
        defer { service.stopMonitoring() }

        try? await Task.sleep(for: .milliseconds(50))

        // Timer delivery is owned by the host run loop, but startMonitoring must refresh now.
        XCTAssertGreaterThanOrEqual(service.fetchCount, 1)
    }

    @MainActor
    func testNetworkFailureUsesExponentialBackoffAndSuccessfulRefreshClearsIt() {
        let service = CountingProviderService()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let firstRetry = service.recordNetworkFailure(now: now)
        XCTAssertEqual(firstRetry, now.addingTimeInterval(60))
        XCTAssertFalse(service.canAttemptNetworkRefresh(at: now.addingTimeInterval(59)))
        XCTAssertTrue(service.canAttemptNetworkRefresh(at: now.addingTimeInterval(60)))

        let secondRetry = service.recordNetworkFailure(now: now.addingTimeInterval(60))
        XCTAssertEqual(secondRetry, now.addingTimeInterval(180))

        service.markRefreshed()
        XCTAssertTrue(service.canAttemptNetworkRefresh(at: now.addingTimeInterval(181)))
    }
}
