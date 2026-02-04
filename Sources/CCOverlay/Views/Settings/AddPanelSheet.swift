import SwiftUI

struct AddPanelSheet: View {
    let configStore: PanelConfigStore
    @Environment(\.dismiss) private var dismiss

    @State private var hoveredType: PanelContentType?

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Panel")
                .font(.system(size: 15, weight: .semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                ForEach(PanelContentType.addableCases) { type in
                    panelTemplateCard(type)
                }
            }

            Button("Cancel") { dismiss() }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 360, height: 220)
    }

    @ViewBuilder
    private func panelTemplateCard(_ type: PanelContentType) -> some View {
        let isHovered = hoveredType == type

        Button {
            let config = PanelConfiguration.defaultPanel(type: type)
            configStore.addPanel(config)
            dismiss()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(isHovered ? .primary : .secondary)

                Text(type.displayName)
                    .font(.system(size: 12, weight: .medium))

                Text(type.panelDescription)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                let size = type.defaultSize
                Text("\(Int(size.width))x\(Int(size.height))")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
            .frame(width: 140, height: 100)
            .glassEffect(
                .regular.interactive(),
                in: .rect(cornerRadius: 12)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hoveredType = $0 ? type : nil }
    }
}
