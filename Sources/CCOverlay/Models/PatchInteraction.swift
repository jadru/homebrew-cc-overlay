import Foundation

/// Maps pointer input into a deliberately small Patch response. Keeping the
/// mapping outside the view makes the companion's movement predictable and
/// independently testable.
struct PatchInteraction: Equatable, Sendable {
    /// A compact footprint keeps the companion decorative instead of covering
    /// the editor, while still leaving room for a live-usage HUD.
    /// The scene keeps the companion and workshop as one grounded cluster,
    /// with a compact status rail beneath it.
    static let overlaySize = CGSize(width: 160, height: 224)
    static let hudMaximumWidth: CGFloat = 144
    static let companionWidth: CGFloat = 112
    static let companionVerticalOffset: CGFloat = -34
    static let companionShadowVerticalOffset: CGFloat = 16
    static let workshopVerticalOffset: CGFloat = -10
    static let hudVerticalOffset: CGFloat = 70
    static let companionRewardOriginY: CGFloat = -24
    static let hudRewardTargetY: CGFloat = 70
    /// All transient companion messages share one contained lane. Keeping the
    /// size and shadow allowance here prevents a future toast from escaping the
    /// fixed-size floating panel.
    static let companionNotificationMaximumWidth: CGFloat = overlaySize.width - 16
    static let companionNotificationMaximumHeight: CGFloat = 28
    static let companionNotificationShadowOutset: CGFloat = 7
    static let companionNotificationVerticalOffset: CGFloat = -84
    static let still = PatchInteraction(
        offset: .zero,
        rotationDegrees: 0,
        scale: 1,
        pointerPosition: .zero
    )

    let offset: CGSize
    let rotationDegrees: Double
    let scale: Double
    /// Normalized pointer position is retained separately from the outer
    /// movement so the companion scene can retain a small depth cue.
    let pointerPosition: CGPoint

    static func pointerResponse(
        at location: CGPoint,
        in size: CGSize = overlaySize
    ) -> PatchInteraction {
        let position = normalizedPosition(for: location, in: size)

        return PatchInteraction(
            offset: CGSize(width: position.x * 5.5, height: position.y * 1.4),
            rotationDegrees: Double(position.x) * 2.2,
            scale: 1.004,
            pointerPosition: position
        )
    }

    var bodyParallax: CGSize {
        CGSize(width: pointerPosition.x * 1.15, height: pointerPosition.y * 0.45)
    }

    var contactShadowOffset: CGSize {
        CGSize(width: pointerPosition.x * 2.8, height: pointerPosition.y * 0.7)
    }

    var contactShadowScale: CGFloat {
        1 - abs(pointerPosition.y) * 0.08
    }

    var contactShadowOpacity: Double {
        0.18 - abs(pointerPosition.y) * 0.045
    }

    static var center: CGPoint {
        CGPoint(x: overlaySize.width / 2, y: overlaySize.height / 2)
    }

    static func containsCenteredElement(
        offset: CGSize,
        contentSize: CGSize,
        scale: CGFloat = 1,
        shadowOutset: CGFloat = 0
    ) -> Bool {
        let scaledSize = CGSize(
            width: contentSize.width * scale,
            height: contentSize.height * scale
        )
        let center = CGPoint(
            x: self.center.x + offset.width,
            y: self.center.y + offset.height
        )
        let frame = CGRect(
            x: center.x - scaledSize.width / 2 - shadowOutset,
            y: center.y - scaledSize.height / 2 - shadowOutset,
            width: scaledSize.width + shadowOutset * 2,
            height: scaledSize.height + shadowOutset * 2
        )
        return CGRect(origin: .zero, size: overlaySize).contains(frame)
    }

    private static func normalizedPosition(for location: CGPoint, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }

        return CGPoint(
            x: clamp((location.x / size.width) * 2 - 1, lower: -1, upper: 1),
            y: clamp((location.y / size.height) * 2 - 1, lower: -1, upper: 1)
        )
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
