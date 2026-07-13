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
        static let menuBarPanelWidth: CGFloat = 420
        static let menuBarPanelEmptyMinHeight: CGFloat = 220
        static let menuBarPanelCompactMinHeight: CGFloat = 330
        static let menuBarPanelMinHeight: CGFloat = 420
        static let menuBarPanelMaxHeight: CGFloat = 560
        static let expandedPillWidth: CGFloat = 300
        static let settingsWidth: CGFloat = 460
        static let settingsHeight: CGFloat = 460
    }

    enum Animation {
        static let press = SwiftUI.Animation.easeOut(duration: 0.12)
        static let selection = SwiftUI.Animation.spring(response: 0.22, dampingFraction: 1)
        static let reveal = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 1)
    }
}
