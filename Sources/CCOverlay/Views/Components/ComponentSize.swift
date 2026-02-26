import SwiftUI

/// Shared size configuration for card-style components.
enum ComponentSize {
    case compact
    case standard

    var headerFont: Font {
        switch self {
        case .compact: return .system(size: 10, weight: .semibold)
        case .standard: return .system(size: 11, weight: .medium)
        }
    }

    var padding: CGFloat {
        switch self {
        case .compact: return 10
        case .standard: return 14
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 14
        case .standard: return 16
        }
    }
}
