import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController {
    private var overlayWindow: OverlayWindow?
    private let usageService: UsageDataService
    private let settings: AppSettings
    private var focusObserver: Any?

    // Apps that keep the overlay visible when focused
    private static let whitelistedBundleIds: Set<String> = [
        // Terminals
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty",
        "com.mitchellh.ghostty",
        "io.alacritty",
        // IDEs & Editors
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.apple.dt.Xcode",
        "com.sublimetext.4",
        "com.sublimetext.3",
        // Claude
        "com.anthropic.claudefordesktop",
        // Conductor
        "com.conductor.app",
    ]

    private static let whitelistedPrefixes: [String] = [
        "com.jetbrains.",  // IntelliJ, WebStorm, PyCharm, etc.
    ]

    init(usageService: UsageDataService, settings: AppSettings) {
        self.usageService = usageService
        self.settings = settings
    }

    func showOverlay() {
        if let existing = overlayWindow {
            if shouldShowForCurrentApp() {
                existing.orderFront(nil)
            }
            startFocusMonitoring()
            return
        }

        let overlayView = OverlayView(
            usageService: usageService,
            settings: settings,
            onSizeChange: { [weak self] size in
                self?.handleSizeChange(size)
            }
        )
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.sizingOptions = []

        let window = OverlayWindow(contentView: hostingView)
        window.isClickThrough = settings.clickThrough
        window.alphaValue = settings.overlayOpacity

        let initialSize = hostingView.fittingSize
        let frame = targetFrame(for: initialSize, at: settings.overlayPosition)
        window.setFrame(frame, display: true)

        if shouldShowForCurrentApp() {
            window.orderFront(nil)
        }

        self.overlayWindow = window
        startFocusMonitoring()
    }

    func hideOverlay() {
        stopFocusMonitoring()
        overlayWindow?.close()
        overlayWindow = nil
    }

    func updatePosition(_ position: OverlayPosition) {
        guard let window = overlayWindow else { return }
        let frame = targetFrame(for: window.frame.size, at: position)
        window.setFrame(frame, display: true)
    }

    func updateClickThrough(_ enabled: Bool) {
        overlayWindow?.isClickThrough = enabled
    }

    func updateOpacity(_ opacity: Double) {
        overlayWindow?.alphaValue = opacity
    }

    /// Re-evaluate overlay visibility when the autoHide setting changes.
    func refreshVisibility() {
        guard let window = overlayWindow else { return }
        if shouldShowForCurrentApp() {
            window.orderFront(nil)
        } else {
            window.orderOut(nil)
        }
    }

    // MARK: - Focus Monitoring

    private func startFocusMonitoring() {
        guard focusObserver == nil else { return }
        focusObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleId = app?.bundleIdentifier
            let pid = app?.processIdentifier ?? -1
            Task { @MainActor in
                self?.handleAppActivation(bundleId: bundleId, pid: pid)
            }
        }
    }

    private func stopFocusMonitoring() {
        if let observer = focusObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            focusObserver = nil
        }
    }

    private func handleAppActivation(bundleId: String?, pid: pid_t) {
        guard settings.overlayAutoHide else {
            overlayWindow?.orderFront(nil)
            return
        }

        // Always show for our own process (e.g. Settings window)
        if pid == ProcessInfo.processInfo.processIdentifier {
            overlayWindow?.orderFront(nil)
            return
        }

        if let bundleId, Self.isWhitelisted(bundleId) {
            overlayWindow?.orderFront(nil)
        } else {
            overlayWindow?.orderOut(nil)
        }
    }

    private func shouldShowForCurrentApp() -> Bool {
        guard settings.overlayAutoHide else { return true }
        guard let app = NSWorkspace.shared.frontmostApplication else { return true }

        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { return true }
        if let bundleId = app.bundleIdentifier, Self.isWhitelisted(bundleId) { return true }
        return false
    }

    private static func isWhitelisted(_ bundleId: String) -> Bool {
        if whitelistedBundleIds.contains(bundleId) { return true }
        for prefix in whitelistedPrefixes where bundleId.hasPrefix(prefix) { return true }
        return false
    }

    // MARK: - Window Sizing

    private func handleSizeChange(_ size: CGSize) {
        guard let window = overlayWindow else { return }
        guard size.width > 0, size.height > 0 else { return }
        let frame = targetFrame(for: size, at: settings.overlayPosition)
        window.setFrame(frame, display: true)
    }

    private func targetFrame(for size: CGSize, at position: OverlayPosition) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(origin: .zero, size: size)
        }
        let screenFrame = screen.visibleFrame
        let margin: CGFloat = 16

        let origin: NSPoint
        switch position {
        case .topRight:
            origin = NSPoint(
                x: screenFrame.maxX - size.width - margin,
                y: screenFrame.maxY - size.height - margin
            )
        case .topLeft:
            origin = NSPoint(
                x: screenFrame.minX + margin,
                y: screenFrame.maxY - size.height - margin
            )
        case .bottomRight:
            origin = NSPoint(
                x: screenFrame.maxX - size.width - margin,
                y: screenFrame.minY + margin
            )
        case .bottomLeft:
            origin = NSPoint(
                x: screenFrame.minX + margin,
                y: screenFrame.minY + margin
            )
        }

        return NSRect(origin: origin, size: size)
    }
}
