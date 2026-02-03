import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindowController: OverlayWindowController?
    private var settingsWindow: NSWindow?
    private var settingsHostingView: NSHostingView<SettingsView>?
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func showOverlay(usageService: UsageDataService, settings: AppSettings) {
        if overlayWindowController == nil {
            overlayWindowController = OverlayWindowController(
                usageService: usageService,
                settings: settings
            )
        }
        overlayWindowController?.showOverlay()
    }

    func hideOverlay() {
        overlayWindowController?.hideOverlay()
    }

    func refreshOverlayVisibility() {
        overlayWindowController?.refreshVisibility()
    }

    func showSettings(settings: AppSettings, usageService: UsageDataService) {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(settings: settings, usageService: usageService)
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "CC-Overlay Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window
        self.settingsHostingView = hostingView
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
