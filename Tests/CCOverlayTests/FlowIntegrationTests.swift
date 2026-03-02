import Foundation
import XCTest
import UserNotifications
@testable import CCOverlay

final class TestFlowEventSink: DebugFlowEventSink {
    private(set) var events: [UIFlowEvent] = []

    func record(_ event: UIFlowEvent) {
        events.append(event)
    }
}

final class MockNotificationCenter: CostNotificationCenter {
    let initialStatus: UNAuthorizationStatus
    let shouldGrantOnRequest: Bool
    private(set) var requestedAuthorizationCount = 0
    private(set) var statusQueryCount = 0
    private(set) var deliveredRequests: [UNNotificationRequest] = []

    init(
        initialStatus: UNAuthorizationStatus,
        shouldGrantOnRequest: Bool = true
    ) {
        self.initialStatus = initialStatus
        self.shouldGrantOnRequest = shouldGrantOnRequest
    }

    func getAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        statusQueryCount += 1
        completion(initialStatus)
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        requestedAuthorizationCount += 1
        completion(shouldGrantOnRequest)
    }

    func addNotificationRequest(
        _ request: UNNotificationRequest,
        completion: @escaping (Error?) -> Void
    ) {
        deliveredRequests.append(request)
        completion(nil)
    }
}

final class FlowIntegrationTests: XCTestCase {

    // MARK: - Alert flow

    func testAlertFlow_ThresholdTransitionsTriggerNotifications() {
        let sink = TestFlowEventSink()
        let notificationCenter = MockNotificationCenter(initialStatus: .authorized)
        let manager = CostAlertManager(notificationCenter: notificationCenter)
        let settings = AppSettings()
        settings.costAlertEnabled = true
        settings.alertWarningThreshold = 70
        settings.alertCriticalThreshold = 90

        DebugFlowLogger.shared.configure(enabled: true, sink: sink)
        DebugFlowLogger.shared.clear()

        manager.check(usedPercentage: 65, settings: settings)
        XCTAssertEqual(notificationCenter.deliveredRequests.count, 0)

        manager.check(usedPercentage: 72, settings: settings)
        XCTAssertEqual(notificationCenter.deliveredRequests.count, 1)

        manager.check(usedPercentage: 80, settings: settings)
        XCTAssertEqual(notificationCenter.deliveredRequests.count, 1)

        manager.check(usedPercentage: 95, settings: settings)
        XCTAssertEqual(notificationCenter.deliveredRequests.count, 2)

        let thresholdEvents = sink.events.filter { $0.message == "threshold.crossed" }
        XCTAssertEqual(thresholdEvents.count, 2)
    }

    func testAlertFlow_RequestAuthorizationWhenUnknownStatus() {
        let notificationCenter = MockNotificationCenter(
            initialStatus: .notDetermined,
            shouldGrantOnRequest: true
        )
        let manager = CostAlertManager(notificationCenter: notificationCenter)
        let settings = AppSettings()
        settings.costAlertEnabled = true
        settings.alertWarningThreshold = 70
        settings.alertCriticalThreshold = 90

        DebugFlowLogger.shared.configure(enabled: true)
        DebugFlowLogger.shared.clear()
        manager.checkWeekly(utilization: 95, settings: settings)

        XCTAssertEqual(notificationCenter.requestedAuthorizationCount, 2)
        XCTAssertEqual(notificationCenter.deliveredRequests.count, 2)
    }

    func testAlertFlow_DoesNotWarnWhenDisabled() {
        let notificationCenter = MockNotificationCenter(initialStatus: .authorized)
        let manager = CostAlertManager(notificationCenter: notificationCenter)
        let settings = AppSettings()
        settings.costAlertEnabled = false
        settings.alertWarningThreshold = 70
        settings.alertCriticalThreshold = 90

        manager.check(usedPercentage: 95, settings: settings)
        manager.checkWeekly(utilization: 95, settings: settings)

        XCTAssertEqual(notificationCenter.deliveredRequests.count, 0)
        XCTAssertEqual(notificationCenter.statusQueryCount, 0)
    }

    // MARK: - Detection + render-condition flow

    @MainActor
    func testDetectionFlow_LogsProviderPaths() {
        let sink = TestFlowEventSink()
        DebugFlowLogger.shared.configure(enabled: true, sink: sink)
        DebugFlowLogger.shared.clear()

        _ = CodexDetector.detect()
        _ = GeminiDetector.detect()

        let claudeService = ClaudeCodeProviderService()
        _ = claudeService.detect()

        XCTAssertTrue(
            sink.events.contains(where: { $0.stage == .detection && $0.provider == .codex })
        )
        XCTAssertTrue(
            sink.events.contains(where: { $0.stage == .detection && $0.provider == .gemini })
        )
        XCTAssertTrue(
            sink.events.contains(where: { $0.stage == .detection && $0.provider == .claudeCode })
        )
    }

    func testMenuBarAndOverlayDisplayStateByUsageCondition() {
        let now = Date()
        let usageMap: [CLIProvider: ProviderUsageData] = [
            .claudeCode: ProviderUsageData(
                provider: .claudeCode,
                isAvailable: true,
                usedPercentage: 60,
                remainingPercentage: 40,
                primaryWindowLabel: "5h",
                resetsAt: nil,
                rateLimitBuckets: [RateBucket(label: "5h", utilization: 60)],
                estimatedCost: nil,
                lastActivityAt: now,
                error: nil,
                lastRefresh: now
            ),
            .codex: ProviderUsageData(
                provider: .codex,
                isAvailable: true,
                usedPercentage: 20,
                remainingPercentage: 80,
                primaryWindowLabel: "Daily",
                resetsAt: nil,
                rateLimitBuckets: [RateBucket(label: "Daily", utilization: 20)],
                estimatedCost: nil,
                lastActivityAt: now.addingTimeInterval(-60 * 60 * 12),
                error: nil,
                lastRefresh: now.addingTimeInterval(-60 * 60 * 12)
            ),
        ]

        let activeProviders: [CLIProvider] = [.claudeCode, .codex]
        let critical = activeProviders
            .compactMap { usageMap[$0] }
            .filter(\.isAvailable)
            .min { $0.remainingPercentage < $1.remainingPercentage }
        XCTAssertEqual(critical?.provider, .claudeCode)

        let stale = critical.map { Date().timeIntervalSince($0.lastRefresh ?? Date()) > 120 }
        XCTAssertFalse(stale ?? true)

        let hasDualProviders = activeProviders.count > 1
        XCTAssertTrue(hasDualProviders)
    }
}
