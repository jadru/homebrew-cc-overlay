import Foundation

/// The visual surface used when CC-Overlay is visible above a coding tool.
///
/// A drawn coding companion is the default overlay; the original usage pill remains
/// available for anyone who prefers its expandable detail surface.
enum OverlayPresentation: String, CaseIterable, Identifiable, Sendable {
    case companion
    case usagePill

    var id: String { rawValue }

    var label: String {
        switch self {
        case .companion:
            "Companion"
        case .usagePill:
            "Usage pill"
        }
    }

    var detail: String {
        switch self {
        case .companion:
            "A drawn pixel companion that turns current headroom into a focused next action."
        case .usagePill:
            "The original expandable usage surface with hover details."
        }
    }
}

/// The companion can disappear completely into the desktop or retain a solid workshop
/// surface for contrast. A glass state is intentionally not included: these
/// options should mean exactly what their labels promise.
enum CompanionBackground: String, CaseIterable, Identifiable, Sendable {
    case transparent
    case opaque

    var id: String { rawValue }

    var label: String {
        switch self {
        case .transparent:
            "Transparent"
        case .opaque:
            "Opaque"
        }
    }

    var detail: String {
        switch self {
        case .transparent:
            "No panel, material, or outline behind your companion."
        case .opaque:
            "A solid pixel-workshop panel behind your companion."
        }
    }
}

extension OverlayPresentation {
    /// Keeps the prior Signal Garden preference working after the companion
    /// pivot without preserving that label in the UI.
    static func fromStoredValue(_ rawValue: String?) -> Self {
        switch rawValue {
        case Self.companion.rawValue, "garden": .companion
        case Self.usagePill.rawValue: .usagePill
        default: .companion
        }
    }
}
