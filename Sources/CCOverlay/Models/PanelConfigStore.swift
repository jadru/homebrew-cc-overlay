import Foundation
import Observation

@Observable
@MainActor
final class PanelConfigStore {
    private(set) var panels: [PanelConfiguration] = []

    private let storageKey = "panelConfigurations"

    init() {
        load()
    }

    func addPanel(_ config: PanelConfiguration) {
        panels.append(config)
        save()
    }

    func removePanel(id: PanelID) {
        panels.removeAll { $0.id == id }
        save()
    }

    func updatePanel(_ config: PanelConfiguration) {
        guard let index = panels.firstIndex(where: { $0.id == config.id }) else { return }
        panels[index] = config
        save()
    }

    func updateFrame(id: PanelID, frame: NSRect) {
        guard let index = panels.firstIndex(where: { $0.id == id }) else { return }
        panels[index].updateFrame(frame)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(panels) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PanelConfiguration].self, from: data)
        else { return }
        panels = decoded
    }
}
