import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, AppRuntimeCoordinating {
    private var hotkeyManager: HotkeyManager?
    private let windowCoordinator = WindowCoordinator()
    private let singleInstanceCoordinator = SingleInstanceCoordinator()
    private let launchAtLoginService = LaunchAtLoginService()
    private var terminationHandler: (@MainActor () -> Void)?
    private var runtimeCoordinator: AppRuntimeCoordinator?
    private var dashboardPanelController: DashboardPanelController?
    private var hasInitialized = false

    let multiService = MultiProviderUsageService()
    let settings = AppSettings()
    let systemMetrics = SystemMetricsService()
    let dockerStorage = DockerStorageService()
    let capacityAlertManager = CapacityAlertManager()
    let updateService = UpdateService()

    private(set) var overlayManager: OverlayManager?
    private(set) var isPrimaryInstance = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        isPrimaryInstance = singleInstanceCoordinator.claimOrActivateExisting(
            isUpdateHandoff: UpdateLaunchHandoff.token(from: CommandLine.arguments) != nil
        )

        if isPrimaryInstance {
            initializeApp()
        } else {
            AppLogger.ui.info("Another CC-Overlay instance is already running; terminating this launch")
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregister()
        runtimeCoordinator?.stop()
        dashboardPanelController?.close()
        overlayManager?.closeOverlay()
        windowCoordinator.closeOnboarding()
        singleInstanceCoordinator.release()
        terminationHandler?()
        terminationHandler = nil
    }

    func setTerminationHandler(_ handler: @escaping @MainActor () -> Void) {
        terminationHandler = handler
    }

    func setupOverlay(
        settings: AppSettings,
        multiService: MultiProviderUsageService,
        systemMetrics: SystemMetricsService,
        dockerStorage: DockerStorageService
    ) {
        AppLogger.ui.debug("setupOverlay called, overlayManager exists: \(self.overlayManager != nil)")
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "overlay.setup",
            details: ["hasManager": "\(overlayManager != nil)"]
        )
        guard overlayManager == nil else { return }
        let manager = OverlayManager(
            settings: settings,
            multiService: multiService,
            systemMetrics: systemMetrics,
            dockerStorage: dockerStorage,
            onShowDashboard: { [weak self] overlayFrame in
                self?.showDashboardPanel(near: overlayFrame)
            },
            onOverlayDisabled: { [weak self] in
                self?.enterOverlayRecoveryMode()
            }
        )

        self.overlayManager = manager
        AppLogger.ui.debug("showOverlay setting: \(settings.showOverlay)")

        if settings.showOverlay {
            manager.showOverlay()
        }
    }

    func startRuntimeCoordinator(
        settings: AppSettings,
        multiService: MultiProviderUsageService,
        systemMetrics: SystemMetricsService,
        capacityAlertManager: CapacityAlertManager
    ) {
        guard runtimeCoordinator == nil else { return }
        let coordinator = AppRuntimeCoordinator(
            appDelegate: self,
            settings: settings,
            multiService: multiService,
            systemMetrics: systemMetrics,
            capacityAlertManager: capacityAlertManager
        )
        runtimeCoordinator = coordinator
        coordinator.start()
    }

    func showDashboardPanel(near overlayFrame: NSRect?) {
        let controller = dashboardPanelController ?? DashboardPanelController(
            multiService: multiService,
            settings: settings,
            systemMetrics: systemMetrics,
            dockerStorage: dockerStorage,
            updateService: updateService
        )
        dashboardPanelController = controller
        controller.show(near: overlayFrame)
    }

    func showDashboard() {
        showDashboardPanel(near: overlayManager?.overlayFrame)
    }

    func applyOverlayVisibility(_ isVisible: Bool) {
        if isVisible {
            NSApp.setActivationPolicy(.accessory)
            overlayManager?.showOverlay()
        } else {
            overlayManager?.hideOverlay()
            updateActivationPolicyForOverlayVisibility()
        }
    }

    func updateUsageVisibility() {
        overlayManager?.updateUsageVisibility()
    }

    func updateOverlayFromSettings() {
        overlayManager?.updateFromSettings()
    }

    func refreshOverlay() {
        overlayManager?.refreshOverlay()
    }

    func toggleOverlay(settings: AppSettings) {
        if settings.showOverlay {
            settings.showOverlay = false
            applyOverlayVisibility(false)
        } else {
            showOverlayFromCommand()
        }
    }

    func showOverlayFromCommand() {
        settings.showOverlay = true
        NSApp.setActivationPolicy(.accessory)
        overlayManager?.showOverlay()
    }

    private func initializeApp() {
        guard isPrimaryInstance, !hasInitialized else { return }
        hasInitialized = true

        AppLogger.ui.info("Initializing app...")
        repairLaunchAtLoginRegistrationIfNeeded()
        DebugFlowLogger.shared.configure(enabled: settings.debugFlowLogging)
        setTerminationHandler { [weak self] in
            self?.multiService.stopMonitoring()
            self?.systemMetrics.stopMonitoring()
            self?.dockerStorage.stop()
            self?.updateService.stopMonitoring()
        }
        multiService.configure(settings: settings)
        multiService.startMonitoring(interval: settings.refreshInterval)
        systemMetrics.startMonitoring()

        updateService.configure(settings: settings)
        updateService.startMonitoring()

        setupOverlay(
            settings: settings,
            multiService: multiService,
            systemMetrics: systemMetrics,
            dockerStorage: dockerStorage
        )
        startRuntimeCoordinator(
            settings: settings,
            multiService: multiService,
            systemMetrics: systemMetrics,
            capacityAlertManager: capacityAlertManager
        )

        if !settings.hasCompletedOnboarding {
            showOnboarding(settings: settings, multiService: multiService, onComplete: {})
        }

        UpdateLaunchHandoff.acknowledgeLaunchIfRequested()
    }

    private func repairLaunchAtLoginRegistrationIfNeeded() {
        do {
            let repaired = try launchAtLoginService.repairIfNeeded(
                isEnabled: settings.launchAtLogin,
                registeredVersion: settings.launchAtLoginRegistrationVersion,
                currentVersion: UpdateService.currentAppVersion
            )
            if repaired {
                settings.launchAtLoginRegistrationVersion = UpdateService.currentAppVersion
                AppLogger.ui.info("Refreshed Launch at login registration for the current app version")
            }
        } catch {
            AppLogger.ui.error("Failed to refresh Launch at login registration: \(error.localizedDescription)")
        }
    }

    func showOnboarding(
        settings: AppSettings,
        multiService: MultiProviderUsageService,
        onComplete: @escaping () -> Void
    ) {
        windowCoordinator.showOnboarding(
            settings: settings,
            multiService: multiService,
            onComplete: onComplete
        )
    }

    func setupHotkey(settings: AppSettings, toggleOverlay: @escaping @MainActor () -> Void) {
        hotkeyManager = HotkeyManager()
        DebugFlowLogger.shared.log(stage: .display, message: "hotkey.configure")
        updateHotkey(settings: settings, toggleOverlay: toggleOverlay)
    }

    func updateHotkey(settings: AppSettings, toggleOverlay: @escaping @MainActor () -> Void) {
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "hotkey.update",
            details: ["enabled": "\(settings.globalHotkeyEnabled)"]
        )
        if settings.globalHotkeyEnabled {
            hotkeyManager?.register(action: toggleOverlay)
        } else {
            hotkeyManager?.unregister()
        }
        updateActivationPolicyForOverlayVisibility()
    }

    private func updateActivationPolicyForOverlayVisibility() {
        let policy: NSApplication.ActivationPolicy = settings.showOverlay || settings.globalHotkeyEnabled
            ? .accessory
            : .regular
        NSApp.setActivationPolicy(policy)
    }

    private func enterOverlayRecoveryMode() {
        guard !settings.showOverlay else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
