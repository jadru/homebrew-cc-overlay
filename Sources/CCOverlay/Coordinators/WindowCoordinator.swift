import AppKit
import SwiftUI

/// Coordinates the lifecycle of the settings window.
@MainActor
final class WindowCoordinator {
    private var settingsWindow: NSWindow?
    private var settingsHostingView: NSHostingView<SettingsView>?

    var isSettingsVisible: Bool {
        settingsWindow?.isVisible ?? false
    }

    func showSettings(
        settings: AppSettings,
        multiService: MultiProviderUsageService,
        updateService: UpdateService
    ) {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            settings: settings,
            multiService: multiService,
            updateService: updateService
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

    func closeSettings() {
        settingsWindow?.close()
    }
}
