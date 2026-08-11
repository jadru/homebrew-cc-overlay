import AppKit
import SwiftUI

/// Coordinates the first-run guide. Day-to-day settings live in the menu's
/// contextual Settings sheet, so they do not create a second navigation tree.
@MainActor
final class WindowCoordinator {
    private var onboardingWindow: NSWindow?

    func showOnboarding(
        settings: AppSettings,
        multiService: MultiProviderUsageService,
        patchProgress: PatchProgressStore,
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
            patchProgress: patchProgress,
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
