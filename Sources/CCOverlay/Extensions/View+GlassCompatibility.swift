import SwiftUI

extension View {
    @ViewBuilder
    func compatGlassCircle(interactive: Bool = false, tint: Color? = nil) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .circle)
                }
            } else if interactive {
                self.glassEffect(.regular.interactive(), in: .circle)
            } else {
                self.glassEffect(.regular, in: .circle)
            }
        } else {
            self
                .background(.ultraThinMaterial, in: Circle())
                .background((tint ?? .clear), in: Circle())
                .overlay(
                    Circle().strokeBorder(
                        Color.white.opacity(interactive ? 0.22 : 0.14),
                        lineWidth: 0.8
                    )
                )
        }
        #else
        self
            .background(.ultraThinMaterial, in: Circle())
            .background((tint ?? .clear), in: Circle())
            .overlay(
                Circle().strokeBorder(
                    Color.white.opacity(interactive ? 0.22 : 0.14),
                    lineWidth: 0.8
                )
            )
        #endif
    }

    @ViewBuilder
    func compatGlassCapsule(interactive: Bool = false, tint: Color? = nil) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .capsule)
                }
            } else if interactive {
                self.glassEffect(.regular.interactive(), in: .capsule)
            } else {
                self.glassEffect(.regular, in: .capsule)
            }
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .background((tint ?? .clear), in: Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        Color.white.opacity(interactive ? 0.22 : 0.14),
                        lineWidth: 0.8
                    )
                )
        }
        #else
        self
            .background(.ultraThinMaterial, in: Capsule())
            .background((tint ?? .clear), in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    Color.white.opacity(interactive ? 0.22 : 0.14),
                    lineWidth: 0.8
                )
            )
        #endif
    }

    @ViewBuilder
    func compatGlassRoundedRect(
        cornerRadius: CGFloat,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            if let tint {
                if interactive {
                    self.glassEffect(
                        .regular.tint(tint).interactive(),
                        in: .rect(cornerRadius: cornerRadius)
                    )
                } else {
                    self.glassEffect(
                        .regular.tint(tint),
                        in: .rect(cornerRadius: cornerRadius)
                    )
                }
            } else if interactive {
                self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            self
                .background(.ultraThinMaterial, in: shape)
                .background((tint ?? .clear), in: shape)
                .overlay(
                    shape.strokeBorder(
                        Color.white.opacity(interactive ? 0.22 : 0.14),
                        lineWidth: 0.8
                    )
                )
        }
        #else
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        self
            .background(.ultraThinMaterial, in: shape)
            .background((tint ?? .clear), in: shape)
            .overlay(
                shape.strokeBorder(
                    Color.white.opacity(interactive ? 0.22 : 0.14),
                    lineWidth: 0.8
                )
            )
        #endif
    }
}
