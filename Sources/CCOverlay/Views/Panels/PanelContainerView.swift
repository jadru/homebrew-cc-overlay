import SwiftUI

struct PanelContainerView<Content: View>: View {
    let config: PanelConfiguration
    let configStore: PanelConfigStore
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false
    @State private var closeHovered = false

    var body: some View {
        if config.contentType == .pill {
            content()
        } else {
            ZStack(alignment: .topTrailing) {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                closeButton
                    .opacity(isHovered ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
            .overlay {
                RoundedRectangle(cornerRadius: config.cornerRadius)
                    .strokeBorder(
                        Color.white.opacity(isHovered ? 0.12 : 0.04),
                        lineWidth: 0.5
                    )
                    .animation(.easeInOut(duration: 0.25), value: isHovered)
            }
            .glassEffect(
                .regular.tint(Color.accentColor.opacity(config.glassTintIntensity)),
                in: .rect(cornerRadius: config.cornerRadius)
            )
            .onHover { isHovered = $0 }
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                configStore.removePanel(id: config.id)
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.secondary.opacity(closeHovered ? 1.0 : 0.7))
                .frame(width: 16, height: 16)
                .glassEffect(.regular, in: .circle)
        }
        .buttonStyle(.borderless)
        .scaleEffect(closeHovered ? 1.15 : 1.0)
        .animation(.spring(duration: 0.2), value: closeHovered)
        .onHover { closeHovered = $0 }
        .padding(6)
    }
}
