import SwiftData
import SwiftUI

@main
struct CCOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var multiService = MultiProviderUsageService()
    @State private var settings = AppSettings()
    @State private var costAlertManager = CostAlertManager()
    @State private var updateService = UpdateService()
    @State private var usageHistoryService: UsageHistoryService?
    @State private var sessionMonitor = SessionMonitor(autoStart: true)
    @State private var hasInitialized = false

    private let modelContainer: ModelContainer? = {
        let schema = Schema([UsageSnapshot.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            AppLogger.data.error("Failed to initialize persistent ModelContainer, falling back to in-memory: \(error)")
            do {
                let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                AppLogger.data.error("Failed to initialize in-memory ModelContainer: \(error)")
                return nil
            }
        }
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                multiService: multiService,
                sessionMonitor: sessionMonitor,
                usageHistoryService: usageHistoryService,
                settings: settings,
                updateService: updateService,
                onOpenSettings: {
                    appDelegate.showSettings(settings: settings, multiService: multiService, updateService: updateService)
                }
            )
            .onAppear {
                initializeApp()
            }
            .onChange(of: multiService.usedPercentage) { _, newValue in
                costAlertManager.check(usedPercentage: newValue, settings: settings)
            }
            .onChange(of: multiService.claudeOAuthUsage.rateLimitBuckets.first(where: { $0.label == "7d" })?.utilization ?? 0) { _, weeklyPct in
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
            .onChange(of: settings.debugFlowLogging) { _, enabled in
                DebugFlowLogger.shared.configure(enabled: enabled)
            }
        } label: {
            MenuBarLabel(multiService: multiService, settings: settings, updateService: updateService)
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

        AppLogger.ui.info("Initializing app...")
        DebugFlowLogger.shared.configure(enabled: settings.debugFlowLogging)
        if usageHistoryService == nil, let modelContainer {
            usageHistoryService = UsageHistoryService(modelContainer: modelContainer)
        }

        if let usageHistoryService {
            usageHistoryService.pruneOldData()
            multiService.configure(settings: settings, usageHistoryService: usageHistoryService)
        } else {
            multiService.configure(settings: settings)
        }

        multiService.startMonitoring(interval: settings.refreshInterval)

        updateService.configure(settings: settings)
        updateService.startMonitoring()

        appDelegate.setupOverlay(settings: settings, multiService: multiService)

        appDelegate.setupHotkey(settings: settings) {
            toggleOverlay()
        }
    }
}
