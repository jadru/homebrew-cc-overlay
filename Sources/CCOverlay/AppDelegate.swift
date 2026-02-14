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
        print("[AppDelegate] setupOverlay called, overlayManager exists: \(overlayManager != nil)")
        guard overlayManager == nil else { return }

        let manager = OverlayManager(
            settings: settings,
            multiService: multiService
        )

        self.overlayManager = manager
        print("[AppDelegate] showOverlay setting: \(settings.showOverlay)")

        if settings.showOverlay {
            manager.showOverlay()
        }
    }

    func showSettings(settings: AppSettings, multiService: MultiProviderUsageService) {
        windowCoordinator.showSettings(
            settings: settings,
            multiService: multiService
        )
    }

    func setupHotkey(settings: AppSettings, toggleOverlay: @escaping @MainActor () -> Void) {
        hotkeyManager = HotkeyManager()
        updateHotkey(settings: settings, toggleOverlay: toggleOverlay)
    }

    func updateHotkey(settings: AppSettings, toggleOverlay: @escaping @MainActor () -> Void) {
        if settings.globalHotkeyEnabled {
            hotkeyManager?.register(action: toggleOverlay)
        } else {
            hotkeyManager?.unregister()
        }
    }
}
