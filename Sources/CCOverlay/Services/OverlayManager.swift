import AppKit
import SwiftUI

enum OverlayVisibilityPolicy {
    static func canPresent(
        presentation: OverlayPresentation,
        hasAvailableProviders: Bool,
        companionAlwaysVisible: Bool
    ) -> Bool {
        hasAvailableProviders
            || (presentation == .companion && companionAlwaysVisible)
    }

    static func shouldShowForActiveApplication(
        presentation: OverlayPresentation,
        companionAlwaysVisible: Bool,
        isSelfApplication: Bool,
        isWhitelistedDeveloperTool: Bool
    ) -> Bool {
        isSelfApplication
            || isWhitelistedDeveloperTool
            || (presentation == .companion && companionAlwaysVisible)
    }
}

@MainActor
private final class MovableOverlayPanel: NSPanel {
    private let interactionState: OverlayInteractionState
    private let allowsContentDrag: Bool
    private var dragStartScreenPoint: NSPoint?
    private var dragStartFrame: NSRect?

    init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool,
        interactionState: OverlayInteractionState,
        allowsContentDrag: Bool = false
    ) {
        self.interactionState = interactionState
        self.allowsContentDrag = allowsContentDrag
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
            guard abs(deltaX) > 1 || abs(deltaY) > 1 else { return }

            interactionState.beginWindowDrag()
            var nextFrame = dragStartFrame.offsetBy(dx: deltaX, dy: deltaY)
            nextFrame.origin = boundedOrigin(for: nextFrame)
            setFrame(nextFrame, display: true)

        case .leftMouseUp:
            super.sendEvent(event)
            interactionState.endPointerSequence()
            dragStartScreenPoint = nil
            dragStartFrame = nil

        default:
            super.sendEvent(event)
        }
    }

    /// The companion remains recoverable even when it is dragged to a screen
    /// edge: at least a 52-point grab area is always visible.
    private func boundedOrigin(for frame: NSRect) -> NSPoint {
        let visibleFrame = screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let visibleGrabArea: CGFloat = 52
        let minX = visibleFrame.minX - frame.width + visibleGrabArea
        let maxX = visibleFrame.maxX - visibleGrabArea
        let minY = visibleFrame.minY - frame.height + visibleGrabArea
        let maxY = visibleFrame.maxY - visibleGrabArea

        return NSPoint(
            x: min(max(frame.origin.x, minX), maxX),
            y: min(max(frame.origin.y, minY), maxY)
        )
    }
}

/// Manages the floating usage pill or interactive Patch companion window.
@MainActor
final class OverlayManager {
    private var window: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private let settings: AppSettings
    private let multiService: MultiProviderUsageService
    private let patchProgress: PatchProgressStore
    private var focusObserver: Any?

    init(
        settings: AppSettings,
        multiService: MultiProviderUsageService,
        patchProgress: PatchProgressStore
    ) {
        self.settings = settings
        self.multiService = multiService
        self.patchProgress = patchProgress
    }

    // MARK: - Public API

    func showOverlay() {
        AppLogger.ui.debug("showOverlay called, window exists: \(self.window != nil)")
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "overlay.show",
            details: ["alreadyVisible": "\(window != nil)"]
        )
        guard OverlayVisibilityPolicy.canPresent(
            presentation: settings.overlayPresentation,
            hasAvailableProviders: !multiService.availableProviders.isEmpty,
            companionAlwaysVisible: settings.companionAlwaysVisible
        ) else {
            hideOverlay()
            return
        }
        if window != nil {
            startFocusMonitoring()
            window?.orderFront(nil)
            return
        }
        createWindow()
        startFocusMonitoring()
        AppLogger.ui.debug("Window created at: \(self.window?.frame.debugDescription ?? "nil")")
    }

    func hideOverlay() {
        DebugFlowLogger.shared.log(stage: .display, message: "overlay.hide")
        stopFocusMonitoring()
        window?.orderOut(nil)
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
        window?.close()
        window = nil
        hostingView = nil
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
                presentation: settings.overlayPresentation,
                hasAvailableProviders: !multiService.availableProviders.isEmpty,
                companionAlwaysVisible: settings.companionAlwaysVisible
              )
        else {
            hideOverlay()
            return
        }
        showOverlay()
    }

    // MARK: - Window Creation

    private func createWindow() {
        switch settings.overlayPresentation {
        case .companion:
            createCompanionWindow()
        case .usagePill:
            createUsagePillWindow()
        }
    }

    private func createUsagePillWindow() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let initialSize = CGSize(width: 120, height: 30)
        let originX = screen.maxX - initialSize.width
        let originY = screen.maxY - initialSize.height

        let interactionState = OverlayInteractionState()
        let panel = MovableOverlayPanel(
            contentRect: NSRect(x: originX, y: originY, width: initialSize.width, height: initialSize.height),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            interactionState: interactionState
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
            multiService: multiService,
            settings: settings,
            interactionState: interactionState,
            onSizeChange: { [weak panel] size in
                Task { @MainActor in
                    guard let panel, size.width > 0, size.height > 0 else { return }
                    var frame = panel.frame
                    let visibleFrame = panel.screen?.visibleFrame
                        ?? NSScreen.main?.visibleFrame
                        ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
                    let margin: CGFloat = 0
                    let oldRight = min(frame.maxX, visibleFrame.maxX - margin)
                    let oldTop = min(frame.maxY, visibleFrame.maxY - margin)
                    frame.size = size
                    let minX = visibleFrame.minX + margin
                    let maxX = visibleFrame.maxX - size.width - margin
                    let minY = visibleFrame.minY + margin
                    let maxY = visibleFrame.maxY - size.height - margin
                    frame.origin.x = minX <= maxX ? min(max(oldRight - size.width, minX), maxX) : visibleFrame.minX
                    frame.origin.y = oldTop - size.height
                    frame.origin.y = minY <= maxY ? min(max(frame.origin.y, minY), maxY) : visibleFrame.minY
                    panel.setFrame(
                        frame,
                        display: true,
                        animate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                    )
                }
            }
        )

        let hosting = NSHostingView(rootView: AnyView(pillView))
        hosting.sizingOptions = []
        panel.contentView = hosting

        panel.alphaValue = 1
        panel.ignoresMouseEvents = settings.pillClickThrough

        panel.orderFront(nil)
        self.window = panel
        self.hostingView = hosting
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "overlay.window.created",
            details: ["presentation": "usagePill", "size": "\(initialSize.width)x\(initialSize.height)"]
        )
    }

    private func createCompanionWindow() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let initialSize = PatchInteraction.overlaySize
        let margin: CGFloat = 24
        let originX = screen.maxX - initialSize.width - margin
        let originY = screen.minY + margin

        let interactionState = OverlayInteractionState()
        let panel = MovableOverlayPanel(
            contentRect: NSRect(x: originX, y: originY, width: initialSize.width, height: initialSize.height),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            interactionState: interactionState,
            allowsContentDrag: true
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
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false

        let hosting = NSHostingView(
            rootView: AnyView(
                PatchOverlayView(
                    multiService: multiService,
                    settings: settings,
                    progress: patchProgress,
                    interactionState: interactionState
                )
            )
        )
        hosting.sizingOptions = []
        panel.contentView = hosting

        panel.orderFront(nil)
        self.window = panel
        self.hostingView = hosting
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "overlay.window.created",
            details: ["presentation": "patchCompanion", "size": "\(initialSize.width)x\(initialSize.height)"]
        )
    }

    // MARK: - Settings Observation

    func updateFromSettings() {
        window?.ignoresMouseEvents = settings.overlayPresentation == .usagePill && settings.pillClickThrough
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

    private func handleAppActivation(bundleId: String?, pid: pid_t) {
        guard settings.showOverlay else {
            window?.orderOut(nil)
            return
        }

        let isSelfApplication = pid == ProcessInfo.processInfo.processIdentifier
        let isWhitelistedDeveloperTool = bundleId.map(DevToolDetector.isWhitelisted) ?? false

        if OverlayVisibilityPolicy.shouldShowForActiveApplication(
            presentation: settings.overlayPresentation,
            companionAlwaysVisible: settings.companionAlwaysVisible,
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
}
