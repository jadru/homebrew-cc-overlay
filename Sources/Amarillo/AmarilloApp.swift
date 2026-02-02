import SwiftUI

@main
struct AmarilloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var usageService = UsageDataService()
    @State private var settings = AppSettings()
    @State private var sessionMonitor = SessionMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                usageService: usageService,
                settings: settings,
                sessionMonitor: sessionMonitor,
                onToggleOverlay: {
                    if settings.showOverlay {
                        appDelegate.showOverlay(usageService: usageService, settings: settings, sessionMonitor: sessionMonitor)
                    } else {
                        appDelegate.hideOverlay()
                    }
                },
                onOpenSettings: {
                    appDelegate.showSettings(settings: settings, usageService: usageService)
                }
            )
            .onAppear {
                usageService.startMonitoring(interval: settings.refreshInterval)
                if settings.showOverlay {
                    appDelegate.showOverlay(usageService: usageService, settings: settings, sessionMonitor: sessionMonitor)
                }
            }
        } label: {
            MenuBarLabel(usageService: usageService, settings: settings, sessionMonitor: sessionMonitor)
        }
        .menuBarExtraStyle(.window)
    }
}
