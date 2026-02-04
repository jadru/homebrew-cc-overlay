import SwiftUI

@main
struct CCOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var usageService = UsageDataService()
    @State private var settings = AppSettings()
    @State private var costAlertManager = CostAlertManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                usageService: usageService,
                settings: settings,
                onToggleOverlay: {
                    toggleOverlay()
                },
                onOpenSettings: {
                    appDelegate.showSettings(settings: settings, usageService: usageService)
                }
            )
            .onAppear {
                usageService.startMonitoring(interval: settings.refreshInterval)

                if settings.showOverlay {
                    appDelegate.showOverlay(usageService: usageService, settings: settings)
                }

                appDelegate.setupHotkey(settings: settings) {
                    toggleOverlay()
                }
            }
            .onChange(of: usageService.usedPercentage) { _, newValue in
                costAlertManager.check(usedPercentage: newValue, settings: settings)
            }
            .onChange(of: usageService.oauthUsage.sevenDay.utilization) { _, weeklyPct in
                costAlertManager.checkWeekly(utilization: weeklyPct, settings: settings)
            }
            .onChange(of: settings.overlayAutoHide) { _, _ in
                appDelegate.refreshOverlayVisibility()
            }
            .onChange(of: settings.globalHotkeyEnabled) { _, _ in
                appDelegate.updateHotkey(settings: settings) {
                    toggleOverlay()
                }
            }
        } label: {
            MenuBarLabel(usageService: usageService, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }

    private func toggleOverlay() {
        settings.showOverlay.toggle()
        if settings.showOverlay {
            appDelegate.showOverlay(usageService: usageService, settings: settings)
        } else {
            appDelegate.hideOverlay()
        }
    }
}
