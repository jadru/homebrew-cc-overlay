import SwiftUI

struct PanelContainerView<Content: View>: View {
    let config: PanelConfiguration
    let configStore: PanelConfigStore
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    var body: some View {
        if config.contentType == .pill {
            // Pill manages its own glass effect
            content()
        } else {
            // Chrome-minimal: pure glass + hover-only close
            ZStack(alignment: .topTrailing) {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isHovered {
                    Button {
                        configStore.removePanel(id: config.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                    .padding(8)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
            .glassEffect(
                .regular.tint(Color.accentColor.opacity(config.glassTintIntensity)),
                in: .rect(cornerRadius: config.cornerRadius)
            )
            .onHover { isHovered = $0 }
        }
    }
}
