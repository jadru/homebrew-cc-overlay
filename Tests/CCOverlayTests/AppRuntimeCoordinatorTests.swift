import XCTest
@testable import CCOverlay

@MainActor
private final class AppRuntimeCoordinatorSpy: AppRuntimeCoordinating {
    var appliedOverlayVisibility: [Bool] = []
    var usageVisibilityUpdateCount = 0
    var overlaySettingsUpdateCount = 0
    var overlayRefreshCount = 0
    var hotkeySetupCount = 0
    var hotkeyUpdateCount = 0
    var overlayToggleCount = 0
    var onOverlaySettingsUpdate: (() -> Void)?

    func applyOverlayVisibility(_ isVisible: Bool) {
        appliedOverlayVisibility.append(isVisible)
    }

    func updateUsageVisibility() {
        usageVisibilityUpdateCount += 1
    }

    func updateOverlayFromSettings() {
        overlaySettingsUpdateCount += 1
        onOverlaySettingsUpdate?()
    }

    func refreshOverlay() {
        overlayRefreshCount += 1
    }

    func setupHotkey(settings: AppSettings, toggleOverlay: @escaping @MainActor () -> Void) {
        hotkeySetupCount += 1
    }

    func updateHotkey(settings: AppSettings, toggleOverlay: @escaping @MainActor () -> Void) {
        hotkeyUpdateCount += 1
    }

    func toggleOverlay(settings: AppSettings) {
        overlayToggleCount += 1
    }
}

@MainActor
final class AppRuntimeCoordinatorTests: XCTestCase {
    func testStartAppliesInitialOverlayHotkeyAndUsageState() throws {
        let (settings, suiteName) = try makeSettings()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        settings.showOverlay = true
        settings.globalHotkeyEnabled = true

        let spy = AppRuntimeCoordinatorSpy()
        let coordinator = AppRuntimeCoordinator(
            appDelegate: spy,
            settings: settings,
            multiService: MultiProviderUsageService(),
            systemMetrics: SystemMetricsService(),
            capacityAlertManager: CapacityAlertManager()
        )

        coordinator.start()

        XCTAssertEqual(spy.appliedOverlayVisibility, [true])
        XCTAssertEqual(spy.hotkeySetupCount, 1)
        XCTAssertEqual(spy.usageVisibilityUpdateCount, 1)
        coordinator.stop()
    }

    func testClickThroughChangeUpdatesTheOverlayOnce() async throws {
        let (settings, suiteName) = try makeSettings()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let updateReceived = expectation(description: "overlay settings updated")
        let spy = AppRuntimeCoordinatorSpy()
        spy.onOverlaySettingsUpdate = { updateReceived.fulfill() }
        let coordinator = AppRuntimeCoordinator(
            appDelegate: spy,
            settings: settings,
            multiService: MultiProviderUsageService(),
            systemMetrics: SystemMetricsService(),
            capacityAlertManager: CapacityAlertManager()
        )

        coordinator.start()
        settings.pillClickThrough = true

        await fulfillment(of: [updateReceived], timeout: 1)
        XCTAssertEqual(spy.overlaySettingsUpdateCount, 1)
        coordinator.stop()
    }

    private func makeSettings() throws -> (AppSettings, String) {
        let suiteName = "AppRuntimeCoordinatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (AppSettings(defaults: defaults), suiteName)
    }
}
