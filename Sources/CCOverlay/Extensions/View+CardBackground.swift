import SwiftUI

/// A view modifier that conditionally applies glass effect or subtle background.
/// Used to avoid nested glass effects in panel hierarchies.
struct CardBackgroundModifier: ViewModifier {
    let useGlass: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if useGlass {
            content
                .compatGlassRoundedRect(cornerRadius: cornerRadius)
        } else {
            content
                .background(
                    shape
                        .fill(Color.surfaceElevated)
                        .overlay(
                            shape
                                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                                .blur(radius: 1)
                                .offset(y: 1)
                                .mask(
                                    shape.fill(
                                        LinearGradient(
                                            colors: [.black, .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                )
                        )
                )
                .overlay(
                    shape.strokeBorder(Color.white.opacity(0.05), lineWidth: 0.75)
                )
                .clipShape(shape)
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
