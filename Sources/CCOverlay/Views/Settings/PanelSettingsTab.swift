import SwiftUI

struct PanelSettingsTab: View {
    let configStore: PanelConfigStore

    @State private var selectedPanelId: PanelID?
    @State private var showingAddPanel = false
    @State private var panelToDelete: PanelID?

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
                        .font(.system(size: 12))
                        .foregroundStyle(panel.isVisible ? .primary : .quaternary)
                        .frame(width: 18, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(panel.isVisible ? Color.accentColor.opacity(0.1) : Color.clear)
                        )

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
                        .fill(panel.isVisible ? .green : .secondary.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
                .tag(panel.id)
                .contextMenu {
                    Button(role: .destructive) {
                        removePanel(id: panel.id)
                    } label: {
                        Label("Delete Panel", systemImage: "trash")
                    }
                }
            }

            Divider()

            HStack {
                Button(action: { showingAddPanel = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(role: .destructive, action: { removeSelectedPanel() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(selectedPanelId != nil ? Color.red.opacity(0.7) : Color.secondary.opacity(0.3))
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
        VStack(spacing: 10) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 30))
                .foregroundStyle(.quaternary)

            Text("Select a panel")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)

            Text("Choose a panel from the sidebar\nto configure its settings")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func removeSelectedPanel() {
        guard let id = selectedPanelId else { return }
        removePanel(id: id)
    }

    private func removePanel(id: PanelID) {
        configStore.removePanel(id: id)
        if selectedPanelId == id {
            selectedPanelId = configStore.panels.first?.id
        }
    }
}
