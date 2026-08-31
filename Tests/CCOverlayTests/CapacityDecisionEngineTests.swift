import XCTest
@testable import CCOverlay

final class CapacityDecisionEngineTests: XCTestCase {
    func testCriticalMacStateBlocksEvenWhenProviderCanRun() {
        let decision = CapacityDecisionEngine.decide(
            providerDecision: providerDecision(.run),
            sample: sample(memoryPressure: .critical)
        )

        XCTAssertEqual(decision.kind, .waitForMac)
        XCTAssertNil(decision.nextSafeAt)
        XCTAssertEqual(decision.systemReadiness.status, .blocked)
    }

    func testProviderRefreshOutranksMacCaution() {
        let decision = CapacityDecisionEngine.decide(
            providerDecision: providerDecision(.refresh),
            sample: sample(cpu: 95)
        )

        XCTAssertEqual(decision.kind, .refresh)
        XCTAssertEqual(decision.systemReadiness.status, .caution)
        XCTAssertTrue(decision.reasons.contains { $0.contains("CPU") })
    }

    func testMacCautionTurnsRunIntoCautiousRunNow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let decision = CapacityDecisionEngine.decide(
            providerDecision: providerDecision(.run),
            sample: sample(availableStorage: 9 * 1_024 * 1_024 * 1_024),
            now: now
        )

        XCTAssertEqual(decision.kind, .runWithCaution)
        XCTAssertEqual(decision.nextSafeAt, now)
        XCTAssertTrue(decision.reasons.contains { $0.contains("storage") })
    }

    func testWaitUsesProviderResetAsNextSafeTime() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let reset = now.addingTimeInterval(20 * 60)
        let decision = CapacityDecisionEngine.decide(
            providerDecision: providerDecision(.wait, resetAt: reset),
            sample: sample(),
            now: now
        )

        XCTAssertEqual(decision.kind, .waitForHeadroom)
        XCTAssertEqual(decision.nextSafeAt, reset)
    }

    func testSetupDoesNotInventNextSafeTime() {
        let decision = CapacityDecisionEngine.decide(
            providerDecision: providerDecision(.setup),
            sample: sample()
        )

        XCTAssertEqual(decision.kind, .setup)
        XCTAssertNil(decision.nextSafeAt)
    }

    private func providerDecision(_ kind: UsageDecision.Kind, resetAt: Date? = nil) -> UsageDecision {
        UsageDecision(
            kind: kind,
            title: "Provider action",
            detail: "Provider detail",
            recommendedProvider: .codex,
            resetAt: resetAt,
            confidence: .high,
            dataQuality: .live,
            reasons: ["Provider reason"]
        )
    }

    private func sample(
        cpu: Double = 30,
        memoryPressure: SystemMemoryPressure = .normal,
        availableStorage: Int64 = 100 * 1_024 * 1_024 * 1_024
    ) -> SystemMetricsSample {
        SystemMetricsSample(
            timestamp: Date(),
            cpuUsagePercentage: cpu,
            memory: SystemMemoryMetrics(
                usedBytes: 8,
                totalBytes: 16,
                swapUsedBytes: 0,
                pressure: memoryPressure
            ),
            network: SystemNetworkMetrics(receivedBytesPerSecond: nil, sentBytesPerSecond: nil),
            storage: SystemStorageMetrics(availableBytes: availableStorage, totalBytes: availableStorage * 2),
            battery: nil,
            thermalState: .nominal
        )
    }
}
