import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindowController: OverlayWindowController?
    private var settingsWindow: NSWindow?
    private var settingsHostingView: NSHostingView<SettingsView>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func showOverlay(usageService: UsageDataService, settings: AppSettings, sessionMonitor: SessionMonitor) {
        if overlayWindowController == nil {
            overlayWindowController = OverlayWindowController(
                usageService: usageService,
                settings: settings,
                sessionMonitor: sessionMonitor
            )
        }
        overlayWindowController?.showOverlay()
    }

    func hideOverlay() {
        overlayWindowController?.hideOverlay()
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
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Amarillo Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window
        self.settingsHostingView = hostingView
    }
}
