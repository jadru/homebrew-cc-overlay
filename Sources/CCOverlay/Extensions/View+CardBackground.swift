import SwiftUI

/// A view modifier that conditionally applies glass effect or subtle background.
/// Used to avoid nested glass effects in panel hierarchies.
struct CardBackgroundModifier: ViewModifier {
    let useGlass: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if useGlass {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.primary.opacity(0.03))
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    /// Applies either glass effect or subtle background based on context.
    /// - Parameters:
    ///   - useGlass: Whether to use glass effect (true) or subtle background (false)
    ///   - cornerRadius: Corner radius for the background shape
    func cardBackground(useGlass: Bool = true, cornerRadius: CGFloat = 16) -> some View {
        modifier(CardBackgroundModifier(useGlass: useGlass, cornerRadius: cornerRadius))
    }
}
