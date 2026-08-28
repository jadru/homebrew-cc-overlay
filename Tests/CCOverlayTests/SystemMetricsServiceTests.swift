import Foundation
import XCTest
@testable import CCOverlay

private final class SequenceSystemMetricsCollector: SystemMetricsCollecting, @unchecked Sendable {
    private let samples: [RawSystemMetrics]
    private var index = 0

    init(_ samples: [RawSystemMetrics]) {
        self.samples = samples
    }

    func read() -> RawSystemMetrics {
        defer { index = min(index + 1, samples.count - 1) }
        return samples[index]
    }
}

private struct EmptyProcessMetricsCollector: SystemProcessMetricsCollecting {
    func readTopProcesses() -> [SystemProcessMetric] { [] }
}

@MainActor
final class SystemMetricsServiceTests: XCTestCase {
    func testSamplerComputesCPUAndNetworkDeltas() throws {
        let start = raw(
            at: Date(timeIntervalSince1970: 100),
            ticks: (user: 20, system: 20, idle: 60, nice: 0),
            received: 100,
            sent: 40
        )
        let current = raw(
            at: Date(timeIntervalSince1970: 102),
            ticks: (user: 40, system: 30, idle: 130, nice: 0),
            received: 260,
            sent: 100
        )

        let sample = SystemMetricsService.makeSample(
            raw: current,
            previous: start,
            memoryPressure: .normal
        )

        XCTAssertEqual(try XCTUnwrap(sample.cpuUsagePercentage), 30, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(sample.network.receivedBytesPerSecond), 80, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(sample.network.sentBytesPerSecond), 30, accuracy: 0.001)
    }

    func testFirstSampleAndCounterResetShowUnavailableDeltas() {
        let first = raw(at: Date(timeIntervalSince1970: 100), received: 500, sent: 200)
        let initialSample = SystemMetricsService.makeSample(
            raw: first,
            previous: nil,
            memoryPressure: .normal
        )
        XCTAssertNil(initialSample.cpuUsagePercentage)
        XCTAssertNil(initialSample.network.receivedBytesPerSecond)
        XCTAssertNil(initialSample.network.sentBytesPerSecond)

        let reset = raw(at: Date(timeIntervalSince1970: 102), received: 4, sent: 2)
        let resetSample = SystemMetricsService.makeSample(
            raw: reset,
            previous: first,
            memoryPressure: .normal
        )
        XCTAssertNil(resetSample.network.receivedBytesPerSecond)
        XCTAssertNil(resetSample.network.sentBytesPerSecond)
    }

    func testSamplerCarriesUnsupportedSwapAndMissingBattery() {
        let sample = SystemMetricsService.makeSample(
            raw: raw(at: Date(), swap: nil, battery: nil, thermal: .fair),
            previous: nil,
            memoryPressure: .warning
        )

        XCTAssertNil(sample.memory.swapUsedBytes)
        XCTAssertNil(sample.battery)
        XCTAssertEqual(sample.memory.pressure, .warning)
        XCTAssertEqual(sample.thermalState, .fair)
    }

    func testBatteryStatusDistinguishesChargingFromConnectedAndCharged() {
        XCTAssertEqual(
            SystemBatteryMetrics(percentage: 100, isCharging: false, isCharged: true, isConnectedToPower: true).statusLabel,
            "charged"
        )
        XCTAssertEqual(
            SystemBatteryMetrics(percentage: 80, isCharging: true, isConnectedToPower: true).statusLabel,
            "charging"
        )
        XCTAssertEqual(
            SystemBatteryMetrics(percentage: 80, isCharging: false, isConnectedToPower: false).statusLabel,
            "on battery"
        )
    }

    func testProcessCPUUsesCoreUnitsForMultiCoreProcesses() {
        XCTAssertEqual(NumberFormatting.formatCoreUsage(503), "5.0 cores")
    }

    func testMemoryPressureTransitionRefreshesCurrentSample() {
        let collector = SequenceSystemMetricsCollector([raw(at: Date()), raw(at: Date().addingTimeInterval(2))])
        let service = SystemMetricsService(
            collector: collector,
            processCollector: EmptyProcessMetricsCollector()
        )

        service.refresh()
        service.updateMemoryPressure(.critical)

        XCTAssertEqual(service.currentSample?.memory.pressure, .critical)
    }

    func testRecentSamplesKeepOnlyTheLatestSixtyMinutes() {
        let now = Date(timeIntervalSince1970: 10_000)
        let samples = [
            sample(at: now.addingTimeInterval(-AppConstants.systemMetricsHistoryInterval - 1)),
            sample(at: now.addingTimeInterval(-30)),
            sample(at: now),
        ]

        let trimmed = SystemMetricsService.trimmedSamples(samples, at: now)

        XCTAssertEqual(trimmed.map(\.timestamp), [now.addingTimeInterval(-30), now])
    }

    func testLowPowerIntervalAndStartStopLifecycle() {
        let service = SystemMetricsService(
            collector: SequenceSystemMetricsCollector([raw(at: Date())]),
            processCollector: EmptyProcessMetricsCollector(),
            isLowPowerModeEnabled: { true }
        )

        XCTAssertEqual(service.samplingInterval(), AppConstants.systemMetricsLowPowerInterval)
        service.startMonitoring()
        XCTAssertTrue(service.isMonitoring)
        XCTAssertNotNil(service.currentSample)
        service.stopMonitoring()
        XCTAssertFalse(service.isMonitoring)
    }

    func testTopProcessesSortBySelectedMetricAndLimitToThree() {
        let processes = [
            SystemProcessMetric(pid: 4, name: "four", cpuUsagePercentage: 20, memoryBytes: 400),
            SystemProcessMetric(pid: 2, name: "two", cpuUsagePercentage: 90, memoryBytes: 200),
            SystemProcessMetric(pid: 3, name: "three", cpuUsagePercentage: 70, memoryBytes: 900),
            SystemProcessMetric(pid: 1, name: "one", cpuUsagePercentage: 70, memoryBytes: 100),
        ]

        XCTAssertEqual(SystemMetricsService.sortedProcesses(processes, by: .cpu).map(\.pid), [2, 1, 3])
        XCTAssertEqual(SystemMetricsService.sortedProcesses(processes, by: .memory).map(\.pid), [3, 4, 2])
    }

    func testSystemMonitorMigrationRemovesPetOnlyDataAndPreservesOtherPreferences() throws {
        let suiteName = "SystemMonitorMigrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Data("pet".utf8), forKey: "patchProgress.v1")
        defaults.set("garden", forKey: "gardenBackground")
        defaults.set("companion", forKey: "companionBackground")
        defaults.set(true, forKey: "companionAlwaysVisible")
        defaults.set(true, forKey: "pillAlwaysExpanded")
        defaults.set(true, forKey: "claudeOAuthEnabled")
        defaults.set(true, forKey: "autoUpdateEnabled")
        defaults.set(true, forKey: "launchAtLogin")

        let settings = AppSettings(defaults: defaults)

        XCTAssertNil(defaults.object(forKey: "patchProgress.v1"))
        XCTAssertNil(defaults.object(forKey: "gardenBackground"))
        XCTAssertNil(defaults.object(forKey: "companionBackground"))
        XCTAssertNil(defaults.object(forKey: "companionAlwaysVisible"))
        XCTAssertNil(defaults.object(forKey: "pillAlwaysExpanded"))
        XCTAssertTrue(settings.claudeOAuthEnabled)
        XCTAssertTrue(settings.autoUpdateEnabled)
        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertEqual(settings.overlayPresentation, .systemMonitor)
        XCTAssertEqual(settings.overlayVisibilityMode, .always)
    }

    func testRetiredMenuBarOnlyPreferenceFallsBackToEveryAppMode() throws {
        let suiteName = "OverlayVisibilityMigrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("systemMonitorV1", forKey: "systemMonitorMigration")
        defaults.set("menuBarOnly", forKey: "overlayVisibilityMode")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.overlayVisibilityMode, .always)
    }

    private func raw(
        at timestamp: Date,
        ticks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)? = (user: 10, system: 10, idle: 80, nice: 0),
        received: UInt64 = 0,
        sent: UInt64 = 0,
        swap: UInt64? = 0,
        battery: SystemBatteryMetrics? = SystemBatteryMetrics(percentage: 70, isCharging: false),
        thermal: SystemThermalState = .nominal
    ) -> RawSystemMetrics {
        RawSystemMetrics(
            timestamp: timestamp,
            cpuTicks: ticks,
            usedMemoryBytes: 8_000,
            totalMemoryBytes: 16_000,
            swapUsedBytes: swap,
            receivedNetworkBytes: received,
            sentNetworkBytes: sent,
            storage: SystemStorageMetrics(availableBytes: 100_000, totalBytes: 200_000),
            battery: battery,
            thermalState: thermal
        )
    }

    private func sample(at timestamp: Date) -> SystemMetricsSample {
        SystemMetricsService.makeSample(
            raw: raw(at: timestamp),
            previous: nil,
            memoryPressure: .normal
        )
    }
}
