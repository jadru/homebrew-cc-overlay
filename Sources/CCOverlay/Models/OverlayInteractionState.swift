import Observation

@Observable
@MainActor
final class OverlayInteractionState {
    var isPointerDown = false
    var isExpanded = false
    private(set) var isDraggingWindow = false
    private var suppressNextPrimaryAction = false

    /// Starts a fresh pointer sequence. A prior drag that did not land on a
    /// button must not suppress the next real click.
    func beginPointerSequence() {
        isPointerDown = true
        isDraggingWindow = false
        suppressNextPrimaryAction = false
    }

    /// Called by the floating companion panel once the pointer crosses into a
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
}

enum OverlayInteractionPolicy {
    nonisolated static func shouldExpand(
        isHovered: Bool,
        isPointerDown: Bool,
        alwaysExpanded: Bool
    ) -> Bool {
        alwaysExpanded || (isHovered && !isPointerDown)
    }
}
