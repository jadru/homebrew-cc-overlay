import XCTest
@testable import CCOverlay

@MainActor
final class MultiProviderUsageServiceTests: XCTestCase {
    func testProviderDetectionParticipatesInLoadingState() async {
        var pendingDetection: CheckedContinuation<Void, Never>?
        var shouldSuspend = true
        var factoryCallCount = 0
        let service = MultiProviderUsageService { _, _ in
            factoryCallCount += 1
            if shouldSuspend {
                shouldSuspend = false
                await withCheckedContinuation { pendingDetection = $0 }
            }
            return nil
        }
        defer { service.stopMonitoring() }

        service.startMonitoring()
        XCTAssertTrue(service.isLoading)

        for _ in 0..<100 where pendingDetection == nil {
            try? await Task.sleep(for: .milliseconds(1))
        }
        guard let pendingDetection else {
            return XCTFail("Provider detection did not start")
        }

        service.refresh()
        await Task.yield()
        XCTAssertEqual(factoryCallCount, 1)

        pendingDetection.resume()
        for _ in 0..<100 where service.isLoading {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertFalse(service.isLoading)
    }

    func testRefreshRemovesProviderAfterAuthenticationIsRevoked() async {
        let claude = MockProviderService(provider: .claudeCode)
        let codex = MockProviderService(provider: .codex)
        let service = MultiProviderUsageService { provider, _ in
            switch provider {
            case .claudeCode: return claude
            case .codex: return codex.revalidationResult ? codex : nil
            }
        }
        defer { service.stopMonitoring() }

        service.startMonitoring()
        await wait(for: service, toContain: [.claudeCode, .codex])

        codex.revalidationResult = false
        service.refresh()

        await wait(for: service, toContain: [.claudeCode])
        XCTAssertEqual(codex.stopMonitoringCallCount, 1)
        XCTAssertFalse(service.usageData(for: .codex).isAvailable)
    }

    private func wait(
        for service: MultiProviderUsageService,
        toContain expectedProviders: [CLIProvider]
    ) async {
        for _ in 0..<100 {
            if service.activeProviders == expectedProviders {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for providers: \(expectedProviders)")
    }
}
