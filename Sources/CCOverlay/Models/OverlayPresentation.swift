import Foundation

/// The visual surface used when CC-Overlay is visible above another app.
enum OverlayPresentation: String, CaseIterable, Identifiable, Sendable {
    case horizontal
    case vertical
    case twoColumn

    var id: String { rawValue }

    var label: String {
        switch self {
        case .horizontal: "Horizontal"
        case .vertical: "Vertical"
        case .twoColumn: "Two columns"
        }
    }

    var detail: String {
        switch self {
        case .horizontal:
            "A compact single row for the smallest footprint."
        case .vertical:
            "A single column with one clear system reading per row."
        case .twoColumn:
            "A balanced grid for quick scanning in a narrower space."
        }
    }

    var initialSize: CGSize {
        switch self {
        case .horizontal: CGSize(width: 222, height: 40)
        case .vertical: CGSize(width: 132, height: 174)
        case .twoColumn: CGSize(width: 178, height: 100)
        }
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
