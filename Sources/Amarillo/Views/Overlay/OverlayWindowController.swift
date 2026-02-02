import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController {
    private var overlayWindow: OverlayWindow?
    private let usageService: UsageDataService
    private let settings: AppSettings
    private let sessionMonitor: SessionMonitor

    init(usageService: UsageDataService, settings: AppSettings, sessionMonitor: SessionMonitor) {
        self.usageService = usageService
        self.settings = settings
        self.sessionMonitor = sessionMonitor
    }

    func showOverlay() {
        if let existing = overlayWindow {
            existing.orderFront(nil)
            return
        }

        let overlayView = OverlayView(
            usageService: usageService,
            settings: settings,
            sessionMonitor: sessionMonitor
        ) { [weak self] size in
            self?.handleContentSizeChange(size)
        }
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.sizingOptions = .intrinsicContentSize

        let window = OverlayWindow(contentView: hostingView)
        window.isClickThrough = settings.clickThrough
        window.alphaValue = settings.overlayOpacity

        // Size to initial content, then position
        let initialSize = hostingView.fittingSize
        window.setContentSize(initialSize)
        positionWindow(window, at: settings.overlayPosition)
        window.orderFront(nil)

        self.overlayWindow = window
    }

    func hideOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
    }

    func updatePosition(_ position: OverlayPosition) {
        guard let window = overlayWindow else { return }
        positionWindow(window, at: position)
    }

    func updateClickThrough(_ enabled: Bool) {
        overlayWindow?.isClickThrough = enabled
    }

    func updateOpacity(_ opacity: Double) {
        overlayWindow?.alphaValue = opacity
    }

    private func handleContentSizeChange(_ size: CGSize) {
        guard let window = overlayWindow else { return }
        window.setContentSize(size)
        positionWindow(window, at: settings.overlayPosition)
    }

    private func positionWindow(_ window: NSWindow, at position: OverlayPosition) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let margin: CGFloat = 16

        var origin: NSPoint
        switch position {
        case .topRight:
            origin = NSPoint(
                x: screenFrame.maxX - windowSize.width - margin,
                y: screenFrame.maxY - windowSize.height - margin
            )
        case .topLeft:
            origin = NSPoint(
                x: screenFrame.minX + margin,
                y: screenFrame.maxY - windowSize.height - margin
            )
        case .bottomRight:
            origin = NSPoint(
                x: screenFrame.maxX - windowSize.width - margin,
                y: screenFrame.minY + margin
            )
        case .bottomLeft:
            origin = NSPoint(
                x: screenFrame.minX + margin,
                y: screenFrame.minY + margin
            )
        }

        window.setFrameOrigin(origin)
    }
}
