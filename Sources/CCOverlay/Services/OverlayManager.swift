import AppKit
import SwiftUI

enum OverlayVisibilityPolicy {
    static func canPresent(
        visibilityMode: OverlayVisibilityMode
    ) -> Bool {
        true
    }

    static func shouldShowForActiveApplication(
        visibilityMode: OverlayVisibilityMode,
        isSelfApplication: Bool,
        isWhitelistedDeveloperTool: Bool
    ) -> Bool {
        switch visibilityMode {
        case .always: true
        case .developerToolsOnly: isSelfApplication || isWhitelistedDeveloperTool
        }
    }
}

enum OverlayScreenPolicy {
    static func screenFrame(
        for overlayFrame: NSRect,
        availableScreenFrames: [NSRect],
        fallback: NSRect
    ) -> NSRect {
        matchingFrame(
            for: overlayFrame,
            availableScreenFrames: availableScreenFrames,
            fallback: fallback
        )
    }

    static func visibleFrame(
        for overlayFrame: NSRect,
        availableScreenFrames: [NSRect],
        fallback: NSRect
    ) -> NSRect {
        matchingFrame(
            for: overlayFrame,
            availableScreenFrames: availableScreenFrames,
            fallback: fallback
        )
    }

    private static func matchingFrame(
        for overlayFrame: NSRect,
        availableScreenFrames: [NSRect],
        fallback: NSRect
    ) -> NSRect {
        let overlappingFrames = availableScreenFrames.compactMap { frame -> (frame: NSRect, area: CGFloat)? in
            let intersection = frame.intersection(overlayFrame)
            let area = intersection.width * intersection.height
            return area > 0 ? (frame, area) : nil
        }
        return overlappingFrames.max(by: { $0.area < $1.area })?.frame ?? fallback
    }

    static func screenAtPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
    }

    static func screenFrame(for overlayFrame: NSRect) -> NSRect {
        let fallback = NSScreen.main?.frame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return screenFrame(
            for: overlayFrame,
            availableScreenFrames: NSScreen.screens.map(\.frame),
            fallback: fallback
        )
    }

    static func visibleFrame(for overlayFrame: NSRect) -> NSRect {
        let fallback = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return visibleFrame(
            for: overlayFrame,
            availableScreenFrames: NSScreen.screens.map(\.visibleFrame),
            fallback: fallback
        )
    }
}

enum OverlayResizePlacementPolicy {
    static func resizedFrame(
        from frame: NSRect,
        to size: CGSize,
        screenFrame: NSRect,
        preservesTrailingEdge: Bool,
        margin: CGFloat = 0
    ) -> NSRect {
        var resizedFrame = frame
        let minX = screenFrame.minX + margin
        let maxX = screenFrame.maxX - size.width - margin
        let minY = screenFrame.minY + margin
        let maxY = screenFrame.maxY - size.height - margin

        if preservesTrailingEdge {
            let oldRight = min(frame.maxX, screenFrame.maxX - margin)
            let oldTop = min(frame.maxY, screenFrame.maxY - margin)
            resizedFrame.origin.x = oldRight - size.width
            resizedFrame.origin.y = oldTop - size.height
        }

        resizedFrame.size = size
        resizedFrame.origin.x = minX <= maxX
            ? min(max(resizedFrame.origin.x, minX), maxX)
            : screenFrame.minX
        resizedFrame.origin.y = minY <= maxY
            ? min(max(resizedFrame.origin.y, minY), maxY)
            : screenFrame.minY
        return resizedFrame
    }
}

enum OverlayDragPlacementPolicy {
    static func bounds(for frame: NSRect, screenFrame: NSRect) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        (
            minX: screenFrame.minX,
            maxX: screenFrame.maxX - frame.width,
            minY: screenFrame.minY,
            maxY: screenFrame.maxY - frame.height
        )
    }
}

@MainActor
private final class OverlayWindowPlacementState {
    private let initialScreenFrame: NSRect
    private var needsInitialPlacement = true
    private(set) var preservesTrailingEdge = true

    init(initialScreenFrame: NSRect) {
        self.initialScreenFrame = initialScreenFrame
    }

    func screenFrame(for overlayFrame: NSRect) -> NSRect {
        defer { needsInitialPlacement = false }
        if needsInitialPlacement { return initialScreenFrame }
        return OverlayScreenPolicy.screenFrame(for: overlayFrame)
    }

    func markUserPositioned() {
        preservesTrailingEdge = false
    }
}

@MainActor
private final class MovableOverlayPanel: NSPanel {
    private let interactionState: OverlayInteractionState
    private let allowsContentDrag: Bool
    private let onDragBegan: (() -> Void)?
    private var dragStartScreenPoint: NSPoint?
    private var dragStartFrame: NSRect?

    init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool,
        interactionState: OverlayInteractionState,
        allowsContentDrag: Bool = false,
        onDragBegan: (() -> Void)? = nil
    ) {
        self.interactionState = interactionState
        self.allowsContentDrag = allowsContentDrag
        self.onDragBegan = onDragBegan
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            interactionState.beginPointerSequence()
            if allowsContentDrag {
                dragStartScreenPoint = convertPoint(toScreen: event.locationInWindow)
                dragStartFrame = frame
            }
            super.sendEvent(event)

        case .leftMouseDragged where allowsContentDrag:
            guard let dragStartScreenPoint, let dragStartFrame else {
                super.sendEvent(event)
                return
            }

            let currentScreenPoint = convertPoint(toScreen: event.locationInWindow)
            let deltaX = currentScreenPoint.x - dragStartScreenPoint.x
            let deltaY = currentScreenPoint.y - dragStartScreenPoint.y
            guard OverlayInteractionPolicy.shouldBeginWindowDrag(
                deltaX: deltaX,
                deltaY: deltaY
            ) else { return }

            if !interactionState.isDraggingWindow {
                interactionState.beginWindowDrag()
                onDragBegan?()
            }
            var nextFrame = dragStartFrame.offsetBy(dx: deltaX, dy: deltaY)
            nextFrame.origin = rubberBandedOrigin(for: nextFrame)
            setFrame(nextFrame, display: true)

        case .leftMouseUp:
            super.sendEvent(event)
            settleFrameInsideScreen()
            interactionState.endPointerSequence()
            dragStartScreenPoint = nil
            dragStartFrame = nil

        default:
            super.sendEvent(event)
        }
    }

    /// Keep the entire overlay visible while allowing it to align exactly with a
    /// physical screen edge, including the areas occupied by the Dock and menu bar.
    private func settleFrameInsideScreen() {
        var settledFrame = frame
        let settledOrigin = boundedOrigin(for: settledFrame)
        guard settledOrigin != settledFrame.origin else { return }

        settledFrame.origin = settledOrigin
        setFrame(
            settledFrame,
            display: true,
            animate: false
        )
    }

    private func rubberBandedOrigin(for frame: NSRect) -> NSPoint {
        let bounds = dragBounds(for: frame)
        let resistanceDistance: CGFloat = 20

        return NSPoint(
            x: rubberBanded(
                frame.origin.x,
                minimum: bounds.minX,
                maximum: bounds.maxX,
                resistanceDistance: resistanceDistance
            ),
            y: rubberBanded(
                frame.origin.y,
                minimum: bounds.minY,
                maximum: bounds.maxY,
                resistanceDistance: resistanceDistance
            )
        )
    }

    private func boundedOrigin(for frame: NSRect) -> NSPoint {
        let bounds = dragBounds(for: frame)

        return NSPoint(
            x: min(max(frame.origin.x, bounds.minX), bounds.maxX),
            y: min(max(frame.origin.y, bounds.minY), bounds.maxY)
        )
    }

    private func dragBounds(for frame: NSRect) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        OverlayDragPlacementPolicy.bounds(
            for: frame,
            screenFrame: OverlayScreenPolicy.screenFrame(for: frame)
        )
    }

    private func rubberBanded(
        _ value: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat,
        resistanceDistance: CGFloat
    ) -> CGFloat {
        if value < minimum {
            return minimum - rubberBandDistance(minimum - value, dimension: resistanceDistance)
        }
        if value > maximum {
            return maximum + rubberBandDistance(value - maximum, dimension: resistanceDistance)
        }
        return value
    }

    private func rubberBandDistance(_ overshoot: CGFloat, dimension: CGFloat) -> CGFloat {
        let resistance: CGFloat = 0.55
        return (overshoot * dimension * resistance) / (dimension + resistance * overshoot)
    }
}

/// Manages the floating system-capacity overlay.
@MainActor
final class OverlayManager {
    private var window: NSPanel?
    private var hostingView: NSHostingView<SystemOverlayView>?
    private let settings: AppSettings
    private let multiService: MultiProviderUsageService
    private let systemMetrics: SystemMetricsService
    private let dockerStorage: DockerStorageService
    private let onShowDashboard: (NSRect) -> Void
    private let onOverlayDisabled: () -> Void
    private var focusObserver: Any?
    private var outsideClickMonitor: Any?
    private var interactionState: OverlayInteractionState?

    init(
        settings: AppSettings,
        multiService: MultiProviderUsageService,
        systemMetrics: SystemMetricsService,
        dockerStorage: DockerStorageService,
        onShowDashboard: @escaping (NSRect) -> Void = { _ in },
        onOverlayDisabled: @escaping () -> Void = {}
    ) {
        self.settings = settings
        self.multiService = multiService
        self.systemMetrics = systemMetrics
        self.dockerStorage = dockerStorage
        self.onShowDashboard = onShowDashboard
        self.onOverlayDisabled = onOverlayDisabled
    }

    // MARK: - Public API

    var overlayFrame: NSRect? {
        window?.frame
    }

    func showOverlay() {
        AppLogger.ui.debug("showOverlay called, window exists: \(self.window != nil)")
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "overlay.show",
            details: ["alreadyVisible": "\(window != nil)"]
        )
        guard OverlayVisibilityPolicy.canPresent(
            visibilityMode: settings.overlayVisibilityMode
        ) else {
            hideOverlay()
            return
        }
        guard shouldShowForFrontmostApplication() else {
            // Keep observing application activation while developer-tools-only
            // mode is hidden, so the next eligible app can reveal the overlay.
            window?.orderOut(nil)
            startFocusMonitoring()
            return
        }
        if window != nil {
            startFocusMonitoring()
            startOutsideClickMonitoring()
            window?.orderFront(nil)
            return
        }
        createWindow()
        startFocusMonitoring()
        startOutsideClickMonitoring()
        AppLogger.ui.debug("Window created at: \(self.window?.frame.debugDescription ?? "nil")")
    }

    func hideOverlay() {
        DebugFlowLogger.shared.log(stage: .display, message: "overlay.hide")
        stopFocusMonitoring()
        stopOutsideClickMonitoring()
        window?.orderOut(nil)
    }

    func disableOverlay() {
        settings.showOverlay = false
        hideOverlay()
        onOverlayDisabled()
    }

    func toggleOverlay() {
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "overlay.toggle",
            details: ["isVisible": "\(window?.isVisible == true)"]
        )
        if window?.isVisible == true {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    func closeOverlay() {
        stopFocusMonitoring()
        stopOutsideClickMonitoring()
        window?.close()
        window = nil
        hostingView = nil
        interactionState = nil
    }

    func refreshOverlay() {
        DebugFlowLogger.shared.log(stage: .display, message: "overlay.refresh")
        let wasVisible = window?.isVisible ?? false
        closeOverlay()
        if wasVisible || settings.showOverlay {
            showOverlay()
        }
    }

    func updateUsageVisibility() {
        guard settings.showOverlay,
              OverlayVisibilityPolicy.canPresent(
                visibilityMode: settings.overlayVisibilityMode
              )
        else {
            hideOverlay()
            return
        }
        showOverlay()
    }

    // MARK: - Window Creation

    private func createWindow() {
        createSystemMonitorWindow()
    }

    private func createSystemMonitorWindow() {
        let screen = OverlayScreenPolicy.screenAtPointer()?.frame
            ?? NSScreen.main?.frame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let initialSize = settings.overlayPresentation.initialSize
        let placementState = OverlayWindowPlacementState(initialScreenFrame: screen)
        let originX = screen.maxX - initialSize.width
        let originY = screen.maxY - initialSize.height

        let interactionState = OverlayInteractionState()
        let panel = MovableOverlayPanel(
            contentRect: NSRect(x: originX, y: originY, width: initialSize.width, height: initialSize.height),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            interactionState: interactionState,
            allowsContentDrag: true,
            onDragBegan: { placementState.markUserPositioned() }
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
        // Handle movement from `MovableOverlayPanel` so the frame follows the
        // pointer delta exactly and a drag cannot also become a metric click.
        panel.isMovableByWindowBackground = false
        panel.isMovable = false

        let overlayView = SystemOverlayView(
            multiService: multiService,
            systemMetrics: systemMetrics,
            dockerStorage: dockerStorage,
            settings: settings,
            interactionState: interactionState,
            onHideOverlay: { [weak self] in
                self?.disableOverlay()
            },
            onQuitApplication: {
                NSApplication.shared.terminate(nil)
            },
            onShowDashboard: { [weak self] in
                guard let self else { return }
                self.onShowDashboard(self.window?.frame ?? .zero)
            },
            onSizeChange: { [weak panel] size in
                Task { @MainActor in
                    guard let panel, size.width > 0, size.height > 0 else { return }
                    let screenFrame = placementState.screenFrame(for: panel.frame)
                    let frame = OverlayResizePlacementPolicy.resizedFrame(
                        from: panel.frame,
                        to: size,
                        screenFrame: screenFrame,
                        preservesTrailingEdge: placementState.preservesTrailingEdge
                    )
                    panel.setFrame(
                        frame,
                        display: true,
                        animate: false
                    )
                }
            }
        )

        let hosting = NSHostingView(rootView: overlayView)
        hosting.sizingOptions = []
        panel.contentView = hosting

        panel.alphaValue = 1
        panel.ignoresMouseEvents = settings.pillClickThrough

        panel.orderFront(nil)
        self.window = panel
        self.hostingView = hosting
        self.interactionState = interactionState
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "overlay.window.created",
            details: [
                "presentation": settings.overlayPresentation.rawValue,
                "size": "\(initialSize.width)x\(initialSize.height)",
            ]
        )
    }

    // MARK: - Settings Observation

    func updateFromSettings() {
        window?.ignoresMouseEvents = settings.pillClickThrough
        updateUsageVisibility()
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

    /// `NSPanel` is non-activating so a SwiftUI popover does not consistently
    /// receive a focus-loss dismissal when the user clicks another app or
    /// display. The monitor only asks SwiftUI to clear its selected detail.
    private func startOutsideClickMonitoring() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.interactionState?.dismissDetailPopoverForExternalClick()
            }
        }
    }

    private func stopOutsideClickMonitoring() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func handleAppActivation(bundleId: String?, pid: pid_t) {
        guard settings.showOverlay else {
            window?.orderOut(nil)
            return
        }

        let isSelfApplication = pid == ProcessInfo.processInfo.processIdentifier
        let isWhitelistedDeveloperTool = bundleId.map(DevToolDetector.isWhitelisted) ?? false

        if !isSelfApplication {
            interactionState?.dismissDetailPopoverForExternalClick()
        }

        if OverlayVisibilityPolicy.shouldShowForActiveApplication(
            visibilityMode: settings.overlayVisibilityMode,
            isSelfApplication: isSelfApplication,
            isWhitelistedDeveloperTool: isWhitelistedDeveloperTool
        ) {
            window?.orderFront(nil)
            DebugFlowLogger.shared.log(
                stage: .display,
                message: "overlay.appActivation",
                details: [
                    "bundle": bundleId ?? "self",
                    "pid": "\(pid)",
                    "action": "show",
                ]
            )
            return
        }

        window?.orderOut(nil)
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "overlay.appActivation",
            details: ["bundle": bundleId ?? "unknown", "action": "hide"]
        )
    }

    private func shouldShowForFrontmostApplication() -> Bool {
        let app = NSWorkspace.shared.frontmostApplication
        return OverlayVisibilityPolicy.shouldShowForActiveApplication(
            visibilityMode: settings.overlayVisibilityMode,
            isSelfApplication: app?.processIdentifier == ProcessInfo.processInfo.processIdentifier,
            isWhitelistedDeveloperTool: app.flatMap(\.bundleIdentifier).map(DevToolDetector.isWhitelisted) ?? false
        )
    }
}
