import SwiftUI

@main
struct CCOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var multiService = MultiProviderUsageService()
    @State private var settings = AppSettings()
    @State private var costAlertManager = CostAlertManager()
    @State private var hasInitialized = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                multiService: multiService,
                settings: settings,
                onOpenSettings: {
                    appDelegate.showSettings(settings: settings, multiService: multiService)
                }
            )
            .onAppear {
                initializeApp()
            }
            .onChange(of: multiService.usedPercentage) { _, newValue in
                costAlertManager.check(usedPercentage: newValue, settings: settings)
            }
            .onChange(of: multiService.claudeOAuthUsage.sevenDay.utilization) { _, weeklyPct in
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
            MenuBarLabel(multiService: multiService, settings: settings)
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
        multiService.configure(settings: settings)
        multiService.startMonitoring(interval: settings.refreshInterval)

        appDelegate.setupOverlay(settings: settings, multiService: multiService)

        appDelegate.setupHotkey(settings: settings) {
            toggleOverlay()
        }
    }
}
