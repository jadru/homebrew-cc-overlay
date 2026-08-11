import Foundation
import XCTest
@testable import CCOverlay

private enum StubNetworkStep {
    case response(statusCode: Int, data: Data, responseURL: URL, delay: TimeInterval)
    case error(URLError.Code, delay: TimeInterval)
}

/// A deterministic URLProtocol for exercising slow and failing network paths without
/// relying on the machine's real network connection.
private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var steps: [StubNetworkStep] = []
    nonisolated(unsafe) private static var observedRequests: [URLRequest] = []

    private var workItem: DispatchWorkItem?

    static func configure(steps: [StubNetworkStep]) {
        lock.lock()
        defer { lock.unlock() }
        self.steps = steps
        observedRequests = []
    }

    static func requests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return observedRequests
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let step = Self.nextStep(for: request)
        let delay: TimeInterval
        switch step {
        case .response(_, _, _, let value), .error(_, let value):
            delay = value
        }

        let item = DispatchWorkItem { [weak self] in
            guard let self, self.workItem?.isCancelled == false else { return }
            self.complete(step)
        }
        workItem = item
        DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: item)
    }

    override func stopLoading() {
        workItem?.cancel()
    }

    private func complete(_ step: StubNetworkStep) {
        guard let client else { return }

        switch step {
        case .response(let statusCode, let data, let responseURL, _):
            let response = HTTPURLResponse(
                url: responseURL,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: data)
            client.urlProtocolDidFinishLoading(self)
        case .error(let code, _):
            client.urlProtocol(self, didFailWithError: URLError(code))
        }
    }

    private static func nextStep(for request: URLRequest) -> StubNetworkStep {
        lock.lock()
        defer { lock.unlock() }
        observedRequests.append(request)
        guard !steps.isEmpty else {
            return .error(.badServerResponse, delay: 0)
        }
        return steps.removeFirst()
    }
}

@MainActor
private final class DelayedCountingProviderService: BaseProviderService {
    private(set) var fetchCount = 0

    init() {
        super.init(provider: .codex)
    }

    override func fetchUsage() async {
        fetchCount += 1
        try? await Task.sleep(for: .milliseconds(30))
        markRefreshed()
    }
}

final class NetworkStressTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.configure(steps: [])
        super.tearDown()
    }

    @MainActor
    func testUpdateCheckRetriesTimeoutThenHandlesSlowSuccess() async {
        let releaseURL = URL(string: "https://github.com/jadru/homebrew-cc-overlay/releases/tag/v99.0.0")!
        StubURLProtocol.configure(steps: [
            .error(.timedOut, delay: 0.005),
            .response(statusCode: 200, data: Data(), responseURL: releaseURL, delay: 0.030),
        ])

        let service = UpdateService(urlSession: makeStubSession(), retryDelay: .milliseconds(1))
        let startedAt = Date()
        await service.checkForUpdates()

        guard case .updateAvailable(let version) = service.updateState else {
            return XCTFail("Expected a successful update check after retry, got \(service.updateState)")
        }
        XCTAssertEqual(version, "99.0.0")
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(startedAt), 0.030)

        let requests = StubURLProtocol.requests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first?.timeoutInterval, AppConstants.updateCheckTimeoutInterval)
    }

    @MainActor
    func testUpdateCheckRetriesTransientServerFailure() async {
        let releaseURL = URL(string: "https://github.com/jadru/homebrew-cc-overlay/releases/tag/v99.0.1")!
        StubURLProtocol.configure(steps: [
            .response(statusCode: 503, data: Data(), responseURL: releaseURL, delay: 0),
            .response(statusCode: 200, data: Data(), responseURL: releaseURL, delay: 0),
        ])

        let service = UpdateService(urlSession: makeStubSession(), retryDelay: .zero)
        await service.checkForUpdates()

        XCTAssertEqual(service.updateState, .updateAvailable(version: "99.0.1"))
        XCTAssertEqual(StubURLProtocol.requests().count, 2)
    }

    func testCodexUsageRequestCompletesAfterSlowResponse() async throws {
        let responseURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
        let data = try JSONSerialization.data(withJSONObject: [
            "plan_type": "pro",
            "rate_limit": [
                "primary_window": [
                    "used_percent": 25,
                    "limit_window_seconds": 18_000,
                    "reset_after_seconds": 3_600,
                    "reset_at": 1_900_000_000,
                ],
            ],
        ])
        StubURLProtocol.configure(steps: [
            .response(statusCode: 200, data: data, responseURL: responseURL, delay: 0.030),
        ])

        let auth = CodexDetector.ChatGPTAuth(accessToken: "test-token", accountId: "account-1", planType: "pro")
        let service = CodexOAuthService(auth: auth, urlSession: makeStubSession())
        let usage = try await service.fetchUsage()

        XCTAssertEqual(usage.primaryWindow?.usedPercent, 25)
        let request = try XCTUnwrap(StubURLProtocol.requests().first)
        XCTAssertEqual(request.timeoutInterval, AppConstants.oauthTimeoutInterval)
        XCTAssertEqual(request.value(forHTTPHeaderField: "chatgpt-account-id"), "account-1")
    }

    @MainActor
    func testRapidRefreshStormCoalescesIntoOneInFlightRequest() async {
        let service = DelayedCountingProviderService()
        service.refresh(forceNetwork: true)
        for _ in 0..<1_000 {
            service.refresh(forceNetwork: true)
        }

        try? await Task.sleep(for: .milliseconds(5))
        XCTAssertEqual(service.fetchCount, 1)
        XCTAssertTrue(service.isLoading)

        try? await Task.sleep(for: .milliseconds(40))
        XCTAssertFalse(service.isLoading)

        service.refresh(forceNetwork: true)
        try? await Task.sleep(for: .milliseconds(5))
        XCTAssertEqual(service.fetchCount, 2)
        service.stopMonitoring()
    }

    @MainActor
    func testFailureStormCapsBackoffAndHonorsServerRetryAfter() {
        let service = DelayedCountingProviderService()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let expectedDelays: [TimeInterval] = [60, 120, 240, 300, 300]

        for delay in expectedDelays {
            XCTAssertEqual(service.recordNetworkFailure(now: now), now.addingTimeInterval(delay))
        }
        XCTAssertEqual(
            service.recordNetworkFailure(retryAfter: 900, now: now),
            now.addingTimeInterval(900)
        )
        XCTAssertFalse(service.canAttemptNetworkRefresh(at: now.addingTimeInterval(899)))
        XCTAssertTrue(service.canAttemptNetworkRefresh(at: now.addingTimeInterval(900)))
    }

    private func makeStubSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
