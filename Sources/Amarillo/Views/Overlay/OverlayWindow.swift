import AppKit

final class OverlayWindow: NSPanel {

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 40),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
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

        // Non-intrusive behavior
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false

        self.contentView = contentView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    var isClickThrough: Bool = false {
        didSet {
            ignoresMouseEvents = isClickThrough
        }
    }
}
