import AppKit
import SwiftUI

@MainActor
final class PanelManager {
    private var controllers: [PanelID: PanelWindowController] = [:]
    private let configStore: PanelConfigStore
    private let settings: AppSettings
    private let usageService: UsageDataService

    init(configStore: PanelConfigStore, settings: AppSettings, usageService: UsageDataService) {
        self.configStore = configStore
        self.settings = settings
        self.usageService = usageService
    }

    func showAllVisiblePanels() {
        ensureDefaultPill()
        for config in configStore.panels where config.isVisible {
            showPanel(config)
        }
    }

    func showPanel(_ config: PanelConfiguration) {
        if controllers[config.id] != nil { return }

        let contentView = buildContentView(for: config)
        let controller = PanelWindowController(
            panelId: config.id,
            configStore: configStore,
            settings: settings
        )
        controller.show(contentView: contentView, config: config)
        controllers[config.id] = controller
    }

    func hidePanel(id: PanelID) {
        controllers[id]?.hide()
    }

    func hideAllPanels() {
        for controller in controllers.values {
            controller.hide()
        }
    }

    func removePanel(id: PanelID) {
        controllers[id]?.close()
        controllers.removeValue(forKey: id)
        configStore.removePanel(id: id)
    }

    func refreshPanel(id: PanelID) {
        guard let config = configStore.panels.first(where: { $0.id == id }) else { return }
        controllers[id]?.close()
        controllers.removeValue(forKey: id)
        if config.isVisible {
            showPanel(config)
        }
    }

    func refreshAllPanels() {
        let ids = Array(controllers.keys)
        for id in ids {
            controllers[id]?.close()
            controllers.removeValue(forKey: id)
        }
        showAllVisiblePanels()
    }

    // MARK: - Pill

    func togglePillVisibility() {
        guard var pillConfig = configStore.panels.first(where: { $0.contentType == .pill }) else { return }

        if let controller = controllers[pillConfig.id] {
            controller.close()
            controllers.removeValue(forKey: pillConfig.id)
            pillConfig.isVisible = false
            configStore.updatePanel(pillConfig)
        } else {
            pillConfig.isVisible = true
            configStore.updatePanel(pillConfig)
            showPanel(pillConfig)
        }
    }

    private func ensureDefaultPill() {
        let hasPill = configStore.panels.contains(where: { $0.contentType == .pill })
        if !hasPill {
            let pill = PanelConfiguration.defaultPanel(type: .pill)
            configStore.addPanel(pill)
        }
    }

    // MARK: - Content Building

    private func buildContentView(for config: PanelConfiguration) -> NSView {
        let view: AnyView
        switch config.contentType {
        case .pill:
            let usageService = self.usageService
            let settings = self.settings
            let controllerId = config.id
            view = AnyView(
                PanelContainerView(config: config, configStore: configStore) {
                    PillView(
                        usageService: usageService,
                        settings: settings,
                        onSizeChange: { [weak self] size in
                            Task { @MainActor in
                                self?.controllers[controllerId]?.updatePillSize(size)
                            }
                        }
                    )
                }
            )
        case .claudeUsage:
            view = AnyView(
                PanelContainerView(config: config, configStore: configStore) {
                    ClaudeUsagePanelView(usageService: self.usageService, settings: self.settings)
                }
            )
        case .tokenPricing:
            view = AnyView(
                PanelContainerView(config: config, configStore: configStore) {
                    TokenPricingPanelView()
                }
            )
        }

        let hostingView = NSHostingView(rootView: view)
        if config.contentType == .pill {
            hostingView.sizingOptions = []
        }
        return hostingView
    }
}
