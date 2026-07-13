import Observation

@Observable
@MainActor
final class OverlayInteractionState {
    var isPointerDown = false
    var isExpanded = false
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
