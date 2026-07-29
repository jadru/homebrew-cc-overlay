import AppKit
import SwiftUI

/// Coordinates the lifecycle of the settings window.
@MainActor
final class WindowCoordinator {
    private var settingsWindow: NSWindow?
    private var settingsHostingView: NSHostingView<SettingsView>?
    private var onboardingWindow: NSWindow?

    var isSettingsVisible: Bool {
        settingsWindow?.isVisible ?? false
    }

    func showSettings(
        settings: AppSettings,
        multiService: MultiProviderUsageService,
        codexProfileStore: CodexAccountProfileStore,
        codexAccountMonitor: CodexAccountMonitor,
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
            codexProfileStore: codexProfileStore,
            codexAccountMonitor: codexAccountMonitor,
            updateService: updateService,
            onShowOnboarding: { [weak self] in
                self?.showOnboarding(
                    settings: settings,
                    multiService: multiService,
                    onComplete: { self?.closeOnboarding() }
                )
            }
        )
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: DesignTokens.Layout.settingsWidth,
                height: DesignTokens.Layout.settingsHeight
            ),
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

    func showOnboarding(
        settings: AppSettings,
        multiService: MultiProviderUsageService,
        onComplete: @escaping () -> Void
    ) {
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = OnboardingView(
            settings: settings,
            multiService: multiService,
            onComplete: { [weak self] in
                self?.closeOnboarding()
                onComplete()
            }
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to CC-Overlay"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    func closeOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }
}
