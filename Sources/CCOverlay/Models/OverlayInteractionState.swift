import CoreGraphics
import Observation

@Observable
@MainActor
final class OverlayInteractionState {
    var isPointerDown = false
    private(set) var isDraggingWindow = false
    private var suppressNextPrimaryAction = false
    private(set) var detailDismissalGeneration = 0
    private var isDetailPopoverPresented = false

    /// Starts a fresh pointer sequence. A prior drag that did not land on a
    /// button must not suppress the next real click.
    func beginPointerSequence() {
        isPointerDown = true
        isDraggingWindow = false
        suppressNextPrimaryAction = false
    }

    /// Called by the floating overlay once the pointer crosses into a
    /// drag. SwiftUI buttons then consume this state instead of granting a
    /// click reward on mouse-up.
    func beginWindowDrag() {
        isDraggingWindow = true
        suppressNextPrimaryAction = true
    }

    func endPointerSequence() {
        isPointerDown = false
        isDraggingWindow = false
    }

    func consumeSuppressedPrimaryAction() -> Bool {
        defer { suppressNextPrimaryAction = false }
        return suppressNextPrimaryAction
    }

    func setDetailPopoverPresented(_ isPresented: Bool) {
        isDetailPopoverPresented = isPresented
    }

    /// The overlay itself is intentionally non-activating. A click in another
    /// app therefore needs an explicit hand-off to close a transient detail
    /// popover without changing the overlay's visibility.
    func dismissDetailPopoverForExternalClick() {
        guard isDetailPopoverPresented else { return }
        isDetailPopoverPresented = false
        detailDismissalGeneration &+= 1
    }
}

enum OverlayInteractionPolicy {
    /// A click on the overlay may include a little pointer jitter. Keep the
    /// click intact until movement clearly expresses an intent to reposition
    /// the floating window.
    static let dragActivationDistance: CGFloat = 10

    nonisolated static func shouldBeginWindowDrag(
        deltaX: CGFloat,
        deltaY: CGFloat,
        threshold: CGFloat = dragActivationDistance
    ) -> Bool {
        let distanceSquared = deltaX * deltaX + deltaY * deltaY
        return distanceSquared >= threshold * threshold
    }

}
