import AppKit
import SwiftUI

@MainActor
final class PanelWindowController {
    let panelId: PanelID
    private var window: PanelWindow?
    private let configStore: PanelConfigStore
    private let settings: AppSettings
    private var focusObserver: Any?

    init(panelId: PanelID, configStore: PanelConfigStore, settings: AppSettings) {
        self.panelId = panelId
        self.configStore = configStore
        self.settings = settings
    }

    func show(contentView: NSView, config: PanelConfiguration) {
        if let existing = window {
            if shouldShowForCurrentApp(config: config) {
                existing.orderFront(nil)
            }
            startFocusMonitoring(config: config)
            return
        }

        let panel = PanelWindow(panelId: panelId, contentView: contentView, config: config)
        panel.isClickThrough = config.clickThrough

        panel.onFrameChange = { [weak self] frame in
            Task { @MainActor in
                self?.configStore.updateFrame(id: config.id, frame: frame)
            }
        }

        if shouldShowForCurrentApp(config: config) {
            panel.orderFront(nil)
        }

        self.window = panel
        startFocusMonitoring(config: config)
    }

    /// Update window frame to match pill content size, preserving top-left origin.
    func updatePillSize(_ size: CGSize) {
        guard let window else { return }
        guard size.width > 0, size.height > 0 else { return }
        var frame = window.frame
        let oldTop = frame.maxY
        frame.size = size
        frame.origin.y = oldTop - size.height
        window.setFrame(frame, display: true)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func close() {
        stopFocusMonitoring()
        window?.close()
        window = nil
    }

    func updateConfig(_ config: PanelConfiguration) {
        window?.alphaValue = config.opacity
        window?.isClickThrough = config.clickThrough
    }

    // MARK: - Focus Monitoring

    private func startFocusMonitoring(config: PanelConfiguration) {
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
                self?.handleAppActivation(bundleId: bundleId, pid: pid, config: config)
            }
        }
    }

    private func stopFocusMonitoring() {
        if let observer = focusObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            focusObserver = nil
        }
    }

    private func handleAppActivation(bundleId: String?, pid: pid_t, config: PanelConfiguration) {
        guard config.autoHideWithDevTools else {
            window?.orderFront(nil)
            return
        }

        if pid == ProcessInfo.processInfo.processIdentifier {
            window?.orderFront(nil)
            return
        }

        if let bundleId, DevToolDetector.isWhitelisted(bundleId) {
            window?.orderFront(nil)
        } else {
            window?.orderOut(nil)
        }
    }

    private func shouldShowForCurrentApp(config: PanelConfiguration) -> Bool {
        guard config.autoHideWithDevTools else { return true }
        guard let app = NSWorkspace.shared.frontmostApplication else { return true }

        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { return true }
        if let bundleId = app.bundleIdentifier, DevToolDetector.isWhitelisted(bundleId) { return true }
        return false
    }
}
