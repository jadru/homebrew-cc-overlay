import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private let windowCoordinator = WindowCoordinator()

    private(set) var overlayManager: OverlayManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func setupOverlay(settings: AppSettings, multiService: MultiProviderUsageService) {
        AppLogger.ui.debug("setupOverlay called, overlayManager exists: \(self.overlayManager != nil)")
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "overlay.setup",
            details: ["hasManager": "\(overlayManager != nil)"]
        )
        guard overlayManager == nil else { return }

        let manager = OverlayManager(
            settings: settings,
            multiService: multiService
        )

        self.overlayManager = manager
        AppLogger.ui.debug("showOverlay setting: \(settings.showOverlay)")

        if settings.showOverlay {
            manager.showOverlay()
        }
    }

    func showSettings(settings: AppSettings, multiService: MultiProviderUsageService, updateService: UpdateService) {
        DebugFlowLogger.shared.log(stage: .display, message: "settings.opened")
        windowCoordinator.showSettings(
            settings: settings,
            multiService: multiService,
            updateService: updateService
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
