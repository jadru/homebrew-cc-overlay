import AppKit

final class PanelWindow: NSPanel {
    let panelId: PanelID
    private let isPill: Bool
    var onFrameChange: ((NSRect) -> Void)?

    init(panelId: PanelID, contentView: NSView, config: PanelConfiguration) {
        self.panelId = panelId
        self.isPill = config.contentType == .pill

        let styleMask: NSWindow.StyleMask = config.isResizable
            ? [.nonactivatingPanel, .titled, .resizable, .fullSizeContentView]
            : [.nonactivatingPanel, .fullSizeContentView]

        super.init(
            contentRect: config.frame,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        // Floating behavior
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
        ]

        // Transparency
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Title bar
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false

        // Pill: drag anywhere, no resize constraints
        if isPill {
            isMovableByWindowBackground = true
        }

        // Size constraints (resizable panels only)
        if config.isResizable {
            minSize = config.contentType.minimumSize
            maxSize = config.contentType.maximumSize
        }

        self.contentView = contentView
        alphaValue = config.opacity

        NotificationCenter.default.addObserver(
            self, selector: #selector(frameDidChange),
            name: NSWindow.didEndLiveResizeNotification, object: self
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(frameDidChange),
            name: NSWindow.didMoveNotification, object: self
        )
    }

    @objc private func frameDidChange() {
        onFrameChange?(frame)
    }

    override var canBecomeKey: Bool { !isPill }
    override var canBecomeMain: Bool { false }

    var isClickThrough: Bool = false {
        didSet { ignoresMouseEvents = isClickThrough }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
