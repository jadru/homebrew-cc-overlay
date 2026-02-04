import AppKit
import Foundation

typealias PanelID = UUID

enum PanelContentType: String, Codable, CaseIterable, Identifiable, Sendable {
    case pill
    case claudeUsage
    case tokenPricing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pill: return "Status Pill"
        case .claudeUsage: return "Claude Usage"
        case .tokenPricing: return "Token Pricing"
        }
    }

    var systemImage: String {
        switch self {
        case .pill: return "circle.fill"
        case .claudeUsage: return "gauge.with.dots.needle.bottom.50percent"
        case .tokenPricing: return "dollarsign.circle"
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .pill: return CGSize(width: 120, height: 30)
        case .claudeUsage: return CGSize(width: 280, height: 360)
        case .tokenPricing: return CGSize(width: 300, height: 320)
        }
    }

    var minimumSize: CGSize {
        switch self {
        case .pill: return CGSize(width: 80, height: 24)
        case .claudeUsage: return CGSize(width: 220, height: 260)
        case .tokenPricing: return CGSize(width: 240, height: 220)
        }
    }

    var maximumSize: CGSize {
        switch self {
        case .pill: return CGSize(width: 260, height: 200)
        default: return CGSize(width: 600, height: 600)
        }
    }

    /// Types available for user to add via Settings
    static var addableCases: [PanelContentType] {
        [.claudeUsage, .tokenPricing]
    }
}

struct PanelConfiguration: Codable, Identifiable, Sendable {
    let id: PanelID
    var contentType: PanelContentType
    var title: String
    var isVisible: Bool

    var originX: Double
    var originY: Double
    var width: Double
    var height: Double

    var opacity: Double
    var glassTintIntensity: Double
    var cornerRadius: Double
    var clickThrough: Bool
    var autoHideWithDevTools: Bool

    var isResizable: Bool { contentType != .pill }

    var frame: NSRect {
        NSRect(x: originX, y: originY, width: width, height: height)
    }

    mutating func updateFrame(_ rect: NSRect) {
        originX = rect.origin.x
        originY = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    static func defaultPanel(type: PanelContentType) -> PanelConfiguration {
        let size = type.defaultSize
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let originX = type == .pill ? screen.maxX - size.width - 16 : 100.0
        let originY = type == .pill ? screen.maxY - size.height - 16 : 100.0

        return PanelConfiguration(
            id: UUID(),
            contentType: type,
            title: type.displayName,
            isVisible: true,
            originX: originX, originY: originY,
            width: size.width, height: size.height,
            opacity: 1.0,
            glassTintIntensity: 0.25,
            cornerRadius: type == .pill ? 50 : 20,
            clickThrough: false,
            autoHideWithDevTools: true
        )
    }
}
