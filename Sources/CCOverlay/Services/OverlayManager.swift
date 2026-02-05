import AppKit
import SwiftUI

/// Manages the floating pill overlay window.
@MainActor
final class OverlayManager {
    private var window: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private let settings: AppSettings
    private let usageService: UsageDataService
    private var focusObserver: Any?

    init(settings: AppSettings, usageService: UsageDataService) {
        self.settings = settings
        self.usageService = usageService
    }

    // MARK: - Public API

    func showOverlay() {
        print("[OverlayManager] showOverlay called, window exists: \(window != nil)")
        if window != nil {
            window?.orderFront(nil)
            return
        }
        createWindow()
        startFocusMonitoring()
        print("[OverlayManager] Window created at: \(window?.frame ?? .zero)")
    }

    func hideOverlay() {
        window?.orderOut(nil)
    }

    func toggleOverlay() {
        if window?.isVisible == true {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    func closeOverlay() {
        stopFocusMonitoring()
        window?.close()
        window = nil
        hostingView = nil
    }

    func refreshOverlay() {
        let wasVisible = window?.isVisible ?? false
        closeOverlay()
        if wasVisible || settings.showOverlay {
            showOverlay()
        }
    }

    // MARK: - Window Creation

    private func createWindow() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let initialSize = CGSize(width: 120, height: 30)
        let originX = screen.maxX - initialSize.width - 16
        let originY = screen.maxY - initialSize.height - 16

        let panel = NSPanel(
            contentRect: NSRect(x: originX, y: originY, width: initialSize.width, height: initialSize.height),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        // Build pill content
        let pillView = PillView(
            usageService: usageService,
            settings: settings,
            onSizeChange: { [weak panel] size in
                Task { @MainActor in
                    guard let panel, size.width > 0, size.height > 0 else { return }
                    var frame = panel.frame
                    let oldTop = frame.maxY
                    frame.size = size
                    frame.origin.y = oldTop - size.height
                    panel.setFrame(frame, display: true)
                }
            }
        )

        let hosting = NSHostingView(rootView: AnyView(pillView))
        hosting.sizingOptions = []
        panel.contentView = hosting

        panel.alphaValue = settings.pillOpacity
        panel.ignoresMouseEvents = settings.pillClickThrough

        panel.orderFront(nil)
        self.window = panel
        self.hostingView = hosting
    }

    // MARK: - Settings Observation

    func updateFromSettings() {
        window?.alphaValue = settings.pillOpacity
        window?.ignoresMouseEvents = settings.pillClickThrough
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
        // Self activation - always show
        if pid == ProcessInfo.processInfo.processIdentifier {
            window?.orderFront(nil)
            return
        }

        // Check if whitelisted dev tool
        if let bundleId, DevToolDetector.isWhitelisted(bundleId) {
            window?.orderFront(nil)
        } else {
            window?.orderOut(nil)
        }
    }
}
