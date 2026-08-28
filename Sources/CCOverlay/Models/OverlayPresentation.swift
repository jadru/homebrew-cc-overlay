import Foundation

/// The visual surface used when CC-Overlay is visible above another app.
enum OverlayPresentation: String, CaseIterable, Identifiable, Sendable {
    case systemMonitor

    var id: String { rawValue }

    var label: String {
        "System monitor"
    }

    var detail: String {
        "CPU, memory, network, system health, and AI usage in one compact overlay."
    }
}

enum OverlayVisibilityMode: String, CaseIterable, Identifiable, Sendable {
    case always
    case developerToolsOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .always: "Every app"
        case .developerToolsOnly: "Developer tools only"
        }
    }

    var detail: String {
        switch self {
        case .always: "Show the compact overlay in every app."
        case .developerToolsOnly: "Show the compact overlay only in recognised developer tools."
        }
    }
}
