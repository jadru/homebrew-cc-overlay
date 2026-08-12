import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private let windowCoordinator = WindowCoordinator()
    private let singleInstanceCoordinator = SingleInstanceCoordinator()
    private var terminationHandler: (@MainActor () -> Void)?

    private(set) var overlayManager: OverlayManager?
    private(set) var isPrimaryInstance = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        isPrimaryInstance = singleInstanceCoordinator.claimOrActivateExisting(
            isUpdateHandoff: UpdateLaunchHandoff.token(from: CommandLine.arguments) != nil
        )

        guard !isPrimaryInstance else { return }
        AppLogger.ui.info("Another CC-Overlay instance is already running; terminating this launch")
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregister()
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
        patchProgress: PatchProgressStore
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
            patchProgress: patchProgress
        )

        self.overlayManager = manager
        AppLogger.ui.debug("showOverlay setting: \(settings.showOverlay)")

        if settings.showOverlay {
            manager.showOverlay()
        }
    }

    func showOnboarding(
        settings: AppSettings,
        multiService: MultiProviderUsageService,
        patchProgress: PatchProgressStore,
        onComplete: @escaping () -> Void
    ) {
        windowCoordinator.showOnboarding(
            settings: settings,
            multiService: multiService,
            patchProgress: patchProgress,
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
    }
}
