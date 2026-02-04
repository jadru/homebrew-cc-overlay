import SwiftUI

struct PanelSettingsTab: View {
    let configStore: PanelConfigStore

    @State private var selectedPanelId: PanelID?
    @State private var showingAddPanel = false

    var body: some View {
        HSplitView {
            panelList
                .frame(minWidth: 160, maxWidth: 200)

            if let id = selectedPanelId,
               let config = configStore.panels.first(where: { $0.id == id }) {
                PanelDetailEditor(config: config, configStore: configStore)
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $showingAddPanel) {
            AddPanelSheet(configStore: configStore)
        }
    }

    // MARK: - Panel List

    @ViewBuilder
    private var panelList: some View {
        VStack(spacing: 0) {
            List(configStore.panels, selection: $selectedPanelId) { panel in
                HStack(spacing: 8) {
                    Image(systemName: panel.contentType.systemImage)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(panel.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)

                        Text(panel.contentType.displayName)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Circle()
                        .fill(panel.isVisible ? .green : .secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
                .tag(panel.id)
            }

            Divider()

            HStack {
                Button(action: { showingAddPanel = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(action: removeSelectedPanel) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedPanelId == nil)
            }
            .padding(8)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("Select a panel to configure")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func removeSelectedPanel() {
        guard let id = selectedPanelId else { return }
        configStore.removePanel(id: id)
        selectedPanelId = configStore.panels.first?.id
    }
}
