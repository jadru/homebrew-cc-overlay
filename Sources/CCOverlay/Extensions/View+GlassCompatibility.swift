import AppKit
import SwiftUI

extension View {
    private var glassFallbackBorderOpacity: Double { 0.18 }

    private var glassFallbackFill: AnyShapeStyle {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            return AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.98))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private func glassFallbackBorder(interactive: Bool) -> Color {
        Color.primary.opacity(interactive ? 0.22 : glassFallbackBorderOpacity)
    }

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
                .background(glassFallbackFill, in: Circle())
                .background((tint ?? .clear), in: Circle())
                .overlay(
                    Circle().strokeBorder(
                        glassFallbackBorder(interactive: interactive),
                        lineWidth: 0.8
                    )
                )
        }
        #else
        self
            .background(glassFallbackFill, in: Circle())
            .background((tint ?? .clear), in: Circle())
            .overlay(
                Circle().strokeBorder(
                    glassFallbackBorder(interactive: interactive),
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
                .background(glassFallbackFill, in: Capsule())
                .background((tint ?? .clear), in: Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        glassFallbackBorder(interactive: interactive),
                        lineWidth: 0.8
                    )
                )
        }
        #else
        self
            .background(glassFallbackFill, in: Capsule())
            .background((tint ?? .clear), in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    glassFallbackBorder(interactive: interactive),
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
                .background(glassFallbackFill, in: shape)
                .background((tint ?? .clear), in: shape)
                .overlay(
                    shape.strokeBorder(
                        glassFallbackBorder(interactive: interactive),
                        lineWidth: 0.8
                    )
                )
        }
        #else
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        self
            .background(glassFallbackFill, in: shape)
            .background((tint ?? .clear), in: shape)
            .overlay(
                shape.strokeBorder(
                    glassFallbackBorder(interactive: interactive),
                    lineWidth: 0.8
                )
            )
        #endif
    }

    @ViewBuilder
    func compatGlassEffectID(_ id: String, in namespace: Namespace.ID) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
