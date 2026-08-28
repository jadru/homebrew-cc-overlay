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
        static let dashboardPanelWidth: CGFloat = 420
        static let settingsWidth: CGFloat = 620
        static let settingsHeight: CGFloat = 620
    }

    enum Animation {
        static let press = SwiftUI.Animation.easeOut(duration: 0.12)
        static let popoverContent = SwiftUI.Animation.easeOut(duration: 0.18)
        static let selection = SwiftUI.Animation.spring(response: 0.22, dampingFraction: 1)
        static let reveal = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 1)
        static let reducedFeedback = SwiftUI.Animation.easeOut(duration: 0.12)
    }
}

enum BannerPresentationMotion {
    static func transition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
    }

    static func animation(reduceMotion: Bool) -> SwiftUI.Animation {
        reduceMotion ? DesignTokens.Animation.reducedFeedback : DesignTokens.Animation.reveal
    }
}
