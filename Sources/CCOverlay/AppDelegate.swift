import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var settingsHostingView: NSHostingView<SettingsView>?
    private var hotkeyManager: HotkeyManager?

    private(set) var panelManager: PanelManager?
    private(set) var panelConfigStore: PanelConfigStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func setupPanels(settings: AppSettings, usageService: UsageDataService) {
        let configStore = PanelConfigStore()
        let manager = PanelManager(
            configStore: configStore,
            settings: settings,
            usageService: usageService
        )

        self.panelConfigStore = configStore
        self.panelManager = manager

        if settings.showOverlay {
            manager.showAllVisiblePanels()
        }
    }

    func showSettings(settings: AppSettings, usageService: UsageDataService) {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            settings: settings,
            usageService: usageService,
            panelConfigStore: panelConfigStore
        )
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 620),
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
