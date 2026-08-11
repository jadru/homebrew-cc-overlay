import SwiftData
import SwiftUI

@main
struct CCOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var codexProfileStore: CodexAccountProfileStore
    @State private var codexAccountMonitor: CodexAccountMonitor
    @State private var multiService: MultiProviderUsageService
    @State private var settings = AppSettings()
    @State private var patchProgress = PatchProgressStore()
    @State private var costAlertManager = CostAlertManager()
    @State private var updateService = UpdateService()
    @State private var sessionMonitor = SessionMonitor(autoStart: false)
    @State private var hasInitialized = false
    private let launchAtLoginService = LaunchAtLoginService()

    init() {
        let profileStore = CodexAccountProfileStore()
        _codexProfileStore = State(initialValue: profileStore)
        _codexAccountMonitor = State(
            initialValue: CodexAccountMonitor(profileStore: profileStore)
        )
        _multiService = State(
            initialValue: MultiProviderUsageService(
                codexHomeProvider: {
                    profileStore.selectedProfile?.codexHome
                }
            )
        )
    }

    private let modelContainer: ModelContainer = {
        let schema = Schema([UsageSnapshot.self])
        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let storeURL = appSupportURL
                .appendingPathComponent("CC-Overlay", isDirectory: true)
                .appendingPathComponent("UsageHistory.store")
            let storeDirectory = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            let config = ModelConfiguration(url: storeURL)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            AppLogger.data.error("Failed to initialize persistent ModelContainer, falling back to in-memory: \(error)")
            do {
                let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                fatalError("Failed to initialize in-memory ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                multiService: multiService,
                codexProfileStore: codexProfileStore,
                codexAccountMonitor: codexAccountMonitor,
                settings: settings,
                patchProgress: patchProgress,
                updateService: updateService
            )
            .onAppear {
                initializeApp()
            }
        } label: {
            MenuBarLabel(multiService: multiService, updateService: updateService, settings: settings)
                .task {
                    initializeApp()
                }
                .onChange(of: multiService.usedPercentage) { _, newValue in
                    costAlertManager.check(usedPercentage: newValue, settings: settings)
                }
                .onChange(of: multiService.claudeOAuthUsage.rateLimitBuckets.first(where: { $0.label == "7d" || $0.label == "1w" })?.utilization ?? 0) { _, weeklyPct in
                    costAlertManager.checkWeekly(utilization: weeklyPct, settings: settings)
                }
                .onChange(of: settings.globalHotkeyEnabled) { _, _ in
                    appDelegate.updateHotkey(settings: settings) {
                        toggleOverlay()
                    }
                }
                .onChange(of: settings.showOverlay) { _, isVisible in
                    applyOverlayVisibility(isVisible)
                }
                .onChange(of: multiService.availableProviders) { _, _ in
                    appDelegate.overlayManager?.updateUsageVisibility()
                    recordActivationIfNeeded()
                }
                .onChange(of: multiService.lastRefresh) { _, _ in
                    multiService.recordCurrentSamples()
                    let tokenObservations = multiService.availableProviders.compactMap { provider -> CompanionTokenObservation? in
                        guard let usage = multiService.usageData(for: provider).tokenBreakdown?.usage else {
                            return nil
                        }
                        return CompanionTokenObservation(
                            sourceID: "provider-\(provider.rawValue.lowercased())",
                            cumulativeTokens: usage.rawTokens
                        )
                    }
                    _ = patchProgress.recordTokenUsage(observations: tokenObservations)
                }
                .onChange(of: codexAccountMonitor.selectedSnapshot) { _, snapshot in
                    guard let snapshot,
                          let lifetimeTokens = snapshot.tokenActivity.lifetimeTokens
                    else { return }
                    _ = patchProgress.recordTokenUsage(
                        observations: [
                            CompanionTokenObservation(
                                sourceID: "codex-account-\(snapshot.profileID.uuidString)",
                                cumulativeTokens: lifetimeTokens
                            ),
                        ]
                    )
                }
                .onChange(of: codexProfileStore.selectedProfileID) { _, profileID in
                    multiService.refresh()
                    if let profileID {
                        Task { await codexAccountMonitor.refresh(profileID) }
                    }
                }
                .onChange(of: settings.pillClickThrough) { _, _ in
                    appDelegate.overlayManager?.updateFromSettings()
                }
                .onChange(of: settings.overlayPresentation) { _, _ in
                    appDelegate.overlayManager?.refreshOverlay()
                }
                .onChange(of: settings.debugFlowLogging) { _, enabled in
                    DebugFlowLogger.shared.configure(enabled: enabled)
                }
        }
        .menuBarExtraStyle(.window)
    }

    private func toggleOverlay() {
        settings.showOverlay.toggle()
        applyOverlayVisibility(settings.showOverlay)
    }

    private func applyOverlayVisibility(_ isVisible: Bool) {
        if isVisible {
            appDelegate.overlayManager?.showOverlay()
        } else {
            appDelegate.overlayManager?.hideOverlay()
        }
    }

    private func initializeApp() {
        guard !hasInitialized else { return }
        hasInitialized = true

        AppLogger.ui.info("Initializing app...")
        repairLaunchAtLoginRegistrationIfNeeded()
        DebugFlowLogger.shared.configure(enabled: settings.debugFlowLogging)
        appDelegate.setTerminationHandler {
            multiService.stopMonitoring()
            codexAccountMonitor.stopMonitoring()
            sessionMonitor.stopMonitoring()
            updateService.stopMonitoring()
        }
        multiService.configure(settings: settings)
        multiService.startMonitoring(interval: settings.refreshInterval)
        codexAccountMonitor.startMonitoring(selectedInterval: settings.refreshInterval)
        sessionMonitor.startMonitoring()

        updateService.configure(settings: settings)
        updateService.startMonitoring()

        appDelegate.setupOverlay(
            settings: settings,
            multiService: multiService,
            patchProgress: patchProgress
        )

        appDelegate.setupHotkey(settings: settings) {
            toggleOverlay()
        }

        if !settings.hasCompletedOnboarding {
            appDelegate.showOnboarding(
                settings: settings,
                multiService: multiService,
                patchProgress: patchProgress,
                onComplete: {}
            )
        }

        UpdateLaunchHandoff.acknowledgeLaunchIfRequested()
    }

    private func recordActivationIfNeeded() {
        guard settings.firstUsageAt == nil, !multiService.availableProviders.isEmpty else { return }
        settings.firstUsageAt = Date()
        AppLogger.data.info("Recorded first usable provider activation")
    }

    private func repairLaunchAtLoginRegistrationIfNeeded() {
        do {
            let repaired = try launchAtLoginService.repairIfNeeded(
                isEnabled: settings.launchAtLogin,
                registeredVersion: settings.launchAtLoginRegistrationVersion,
                currentVersion: UpdateService.currentAppVersion
            )
            if repaired {
                settings.launchAtLoginRegistrationVersion = UpdateService.currentAppVersion
                AppLogger.ui.info("Refreshed Launch at login registration for the current app version")
            }
        } catch {
            AppLogger.ui.error("Failed to refresh Launch at login registration: \(error.localizedDescription)")
        }
    }
}
