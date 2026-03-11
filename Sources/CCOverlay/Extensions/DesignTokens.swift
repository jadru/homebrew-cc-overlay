import SwiftUI

enum DesignTokens {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum CornerRadius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let card: CGFloat = 16
        static let panel: CGFloat = 20
        static let pill: CGFloat = 999
    }

    enum Layout {
        static let sidebarWidth: CGFloat = 52
        static let sidebarButton: CGFloat = 40
        static let menuBarPanelWidth: CGFloat = 392
        static let menuBarPanelMinHeight: CGFloat = 460
        static let menuBarPanelMaxHeight: CGFloat = 620
        static let expandedPillWidth: CGFloat = 300
        static let settingsWidth: CGFloat = 460
        static let settingsHeight: CGFloat = 620
    }

    enum Animation {
        static let quick = SwiftUI.Animation.snappy(duration: 0.2)
        static let selection = SwiftUI.Animation.spring(response: 0.34, dampingFraction: 0.84)
        static let bounce = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.58)
        static let reveal = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.86)
        static let pulse = SwiftUI.Animation.easeInOut(duration: 1.15).repeatForever(autoreverses: true)
    }
}
