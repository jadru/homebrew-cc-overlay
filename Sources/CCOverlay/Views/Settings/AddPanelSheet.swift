import SwiftUI

struct AddPanelSheet: View {
    let configStore: PanelConfigStore
    @Environment(\.dismiss) private var dismiss

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
        }
        .padding(20)
        .frame(width: 360, height: 200)
    }

    @ViewBuilder
    private func panelTemplateCard(_ type: PanelContentType) -> some View {
        Button {
            let config = PanelConfiguration.defaultPanel(type: type)
            configStore.addPanel(config)
            dismiss()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)

                Text(type.displayName)
                    .font(.system(size: 12, weight: .medium))

                let size = type.defaultSize
                Text("\(Int(size.width))x\(Int(size.height))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 130, height: 90)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
