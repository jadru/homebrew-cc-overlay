import AppKit
import SwiftUI

/// Presents the full dashboard only when the user asks for details from the
/// floating overlay. AppKit owns panel lifetime; SwiftUI continues to own all
/// dashboard state and rendering.
@MainActor
final class DashboardPanelController: NSObject, NSWindowDelegate {
    private let multiService: MultiProviderUsageService
    private let settings: AppSettings
    private let systemMetrics: SystemMetricsService
    private let dockerStorage: DockerStorageService
    private let updateService: UpdateService
    private var panel: NSPanel?
    private var anchorFrame: NSRect?
    private var outsideClickMonitor: Any?

    init(
        multiService: MultiProviderUsageService,
        settings: AppSettings,
        systemMetrics: SystemMetricsService,
        dockerStorage: DockerStorageService,
        updateService: UpdateService
    ) {
        self.multiService = multiService
        self.settings = settings
        self.systemMetrics = systemMetrics
        self.dockerStorage = dockerStorage
        self.updateService = updateService
    }

    func show(near overlayFrame: NSRect?) {
        anchorFrame = overlayFrame
        let panel = panel ?? makePanel()
        self.panel = panel
        resizePanel(to: panel.contentView?.fittingSize ?? .zero, animated: false)
        positionPanel(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        startOutsideClickMonitoring()
    }

    func close() {
        stopOutsideClickMonitoring()
        panel?.close()
        panel = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        // A SwiftUI popover becomes key while the dashboard itself is still
        // visible. This is especially common for our non-activating overlay
        // app, so key-window changes are not a reliable outside-click signal.
    }

    func windowWillClose(_ notification: Notification) {
        stopOutsideClickMonitoring()
        panel = nil
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: DesignTokens.Layout.dashboardPanelWidth, height: 250),
            styleMask: [.titled, .closable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "CC Overlay"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = DashboardPanelCollectionBehaviorPolicy.behavior
        // The global pointer monitor below hides the dashboard for genuine
        // external clicks. Letting AppKit hide on deactivation would also hide
        // it whenever one of its own metric popovers becomes key.
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let dashboard = DashboardPanelView(
            multiService: multiService,
            settings: settings,
            systemMetrics: systemMetrics,
            dockerStorage: dockerStorage,
            updateService: updateService,
            onSizeChange: { [weak self] size in
                self?.resizePanel(to: size, animated: false)
            }
        )
        panel.contentView = NSHostingView(rootView: dashboard)
        return panel
    }

    private func resizePanel(to size: CGSize, animated: Bool) {
        guard let panel, size.width > 0, size.height > 0 else { return }
        var frame = panel.frame
        frame.size = size
        panel.setFrame(frame, display: true, animate: animated)
        positionPanel(panel)
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let anchorFrame else {
            panel.center()
            return
        }

        let visibleFrame = OverlayScreenPolicy.visibleFrame(for: anchorFrame)
        panel.setFrameOrigin(
            DashboardPanelPlacementPolicy.origin(
                panelSize: panel.frame.size,
                anchorFrame: anchorFrame,
                visibleFrame: visibleFrame
            )
        )
    }

    private func startOutsideClickMonitoring() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            let location = event.locationInWindow
            Task { @MainActor in
                guard let self, self.panel?.isVisible == true else { return }
                guard DashboardPanelDismissalPolicy.shouldDismiss(
                    isExternalPointerEvent: true,
                    isInsideDashboard: self.containsDashboardInteraction(at: location)
                ) else { return }
                self.panel?.orderOut(nil)
            }
        }
    }

    private func stopOutsideClickMonitoring() {
        guard let outsideClickMonitor else { return }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }

    private func containsDashboardInteraction(at point: NSPoint) -> Bool {
        guard let panel else { return false }
        return DashboardPanelInteractionPolicy.containsDashboardInteraction(
            at: point,
            dashboardPanel: panel,
            applicationWindows: NSApp.windows
        )
    }
}

@MainActor
enum DashboardPanelInteractionPolicy {
    static func containsDashboardInteraction(
        at point: NSPoint,
        dashboardPanel: NSWindow,
        applicationWindows: [NSWindow]
    ) -> Bool {
        applicationWindows.contains { window in
            window.isVisible
                && window.frame.contains(point)
                && belongsToDashboard(window, dashboardPanel: dashboardPanel)
        }
    }

    private static func belongsToDashboard(
        _ window: NSWindow,
        dashboardPanel: NSWindow
    ) -> Bool {
        var candidate: NSWindow? = window
        while let currentWindow = candidate {
            if currentWindow === dashboardPanel { return true }
            candidate = currentWindow.parent
        }
        return false
    }
}

enum DashboardPanelPlacementPolicy {
    static func origin(
        panelSize: CGSize,
        anchorFrame: NSRect,
        visibleFrame: NSRect,
        margin: CGFloat = 8
    ) -> NSPoint {
        var origin = NSPoint(
            x: anchorFrame.maxX - panelSize.width,
            y: anchorFrame.minY - panelSize.height - margin
        )
        if origin.y < visibleFrame.minY {
            origin.y = anchorFrame.maxY + margin
        }

        let maximumX = max(visibleFrame.minX, visibleFrame.maxX - panelSize.width)
        let maximumY = max(visibleFrame.minY, visibleFrame.maxY - panelSize.height)
        origin.x = min(max(origin.x, visibleFrame.minX), maximumX)
        origin.y = min(max(origin.y, visibleFrame.minY), maximumY)
        return origin
    }
}

enum DashboardPanelCollectionBehaviorPolicy {
    /// `canJoinAllSpaces` and `moveToActiveSpace` are mutually exclusive in
    /// AppKit. The dashboard follows the overlay across Spaces, including
    /// full-screen apps, so it deliberately uses the former only.
    static let behavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
    ]
}

enum DashboardPanelDismissalPolicy {
    /// A dashboard metric popover is a child interaction, even when it becomes
    /// key. Only a pointer event delivered outside this application dismisses
    /// the dashboard.
    static func shouldDismiss(
        isExternalPointerEvent: Bool,
        isInsideDashboard: Bool
    ) -> Bool {
        isExternalPointerEvent && !isInsideDashboard
    }
}
