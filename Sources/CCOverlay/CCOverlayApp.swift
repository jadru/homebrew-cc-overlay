import SwiftUI

@main
struct CCOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var usageService = UsageDataService()
    @State private var settings = AppSettings()
    @State private var costAlertManager = CostAlertManager()
    @State private var hasInitialized = false

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
                initializeApp()
            }
            .onChange(of: usageService.usedPercentage) { _, newValue in
                costAlertManager.check(usedPercentage: newValue, settings: settings)
            }
            .onChange(of: usageService.oauthUsage.sevenDay.utilization) { _, weeklyPct in
                costAlertManager.checkWeekly(utilization: weeklyPct, settings: settings)
            }
            .onChange(of: settings.globalHotkeyEnabled) { _, _ in
                appDelegate.updateHotkey(settings: settings) {
                    toggleOverlay()
                }
            }
            .onChange(of: settings.pillOpacity) { _, _ in
                appDelegate.overlayManager?.updateFromSettings()
            }
            .onChange(of: settings.pillClickThrough) { _, _ in
                appDelegate.overlayManager?.updateFromSettings()
            }
        } label: {
            MenuBarLabel(usageService: usageService, settings: settings)
                .task {
                    initializeApp()
                }
        }
        .menuBarExtraStyle(.window)
    }

    private func toggleOverlay() {
        settings.showOverlay.toggle()
        if settings.showOverlay {
            appDelegate.overlayManager?.showOverlay()
        } else {
            appDelegate.overlayManager?.hideOverlay()
        }
    }

    private func initializeApp() {
        guard !hasInitialized else { return }
        hasInitialized = true

        print("[CCOverlayApp] Initializing app...")
        usageService.startMonitoring(interval: settings.refreshInterval)

        appDelegate.setupOverlay(settings: settings, usageService: usageService)

        appDelegate.setupHotkey(settings: settings) {
            toggleOverlay()
        }
    }
}
