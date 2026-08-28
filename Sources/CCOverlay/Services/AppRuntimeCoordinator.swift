import Foundation
import Observation

@MainActor
protocol AppRuntimeCoordinating: AnyObject {
    func applyOverlayVisibility(_ isVisible: Bool)
    func updateUsageVisibility()
    func updateOverlayFromSettings()
    func refreshOverlay()
    func setupHotkey(settings: AppSettings, toggleOverlay: @escaping @MainActor () -> Void)
    func updateHotkey(settings: AppSettings, toggleOverlay: @escaping @MainActor () -> Void)
    func toggleOverlay(settings: AppSettings)
}

/// Keeps app-wide side effects active while the dashboard panel is closed.
/// The overlay app has no persistent SwiftUI scene, so this coordinator
/// observes runtime state independently of on-demand views.
@MainActor
final class AppRuntimeCoordinator {
    private weak var appDelegate: (any AppRuntimeCoordinating)?
    private let settings: AppSettings
    private let multiService: MultiProviderUsageService
    private let systemMetrics: SystemMetricsService
    private let capacityAlertManager: CapacityAlertManager
    private var isRunning = false

    init(
        appDelegate: any AppRuntimeCoordinating,
        settings: AppSettings,
        multiService: MultiProviderUsageService,
        systemMetrics: SystemMetricsService,
        capacityAlertManager: CapacityAlertManager
    ) {
        self.appDelegate = appDelegate
        self.settings = settings
        self.multiService = multiService
        self.systemMetrics = systemMetrics
        self.capacityAlertManager = capacityAlertManager
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        DebugFlowLogger.shared.configure(enabled: settings.debugFlowLogging)
        applyOverlayVisibility()
        configureHotkey()
        updateUsageVisibility()
        recordActivationIfNeeded()

        observeUsage()
        observeWeeklyUsage()
        observeSystemMetrics()
        observeOverlayVisibility()
        observeHotkey()
        observeProviderAvailability()
        observeRefreshes()
        observeClickThrough()
        observeVisibilityMode()
        observeDebugLogging()
    }

    func stop() {
        isRunning = false
    }

    private func observeUsage() {
        withObservationTracking {
            for provider in multiService.activeProviders {
                let usage = multiService.usageData(for: provider)
                _ = usage.isAvailable
                _ = usage.usedPercentage
            }
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.checkUsageThresholds()
                self.observeUsage()
            }
        }
    }

    private func observeWeeklyUsage() {
        withObservationTracking {
            for provider in multiService.activeProviders {
                _ = multiService.usageData(for: provider).rateLimitBuckets
            }
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.checkWeeklyUsageThresholds()
                self.observeWeeklyUsage()
            }
        }
    }

    private func observeSystemMetrics() {
        withObservationTracking { _ = systemMetrics.lastRefresh } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.capacityAlertManager.checkSystem(sample: self.systemMetrics.currentSample)
                self.observeSystemMetrics()
            }
        }
    }

    private func observeOverlayVisibility() {
        withObservationTracking { _ = settings.showOverlay } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.applyOverlayVisibility()
                self.observeOverlayVisibility()
            }
        }
    }

    private func observeHotkey() {
        withObservationTracking { _ = settings.globalHotkeyEnabled } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.updateHotkey()
                self.observeHotkey()
            }
        }
    }

    private func observeProviderAvailability() {
        withObservationTracking { _ = multiService.availableProviders } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.updateUsageVisibility()
                self.recordActivationIfNeeded()
                self.observeProviderAvailability()
            }
        }
    }

    private func observeRefreshes() {
        withObservationTracking { _ = multiService.lastRefresh } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.multiService.recordCurrentSamples()
                self.observeRefreshes()
            }
        }
    }

    private func observeClickThrough() {
        withObservationTracking { _ = settings.pillClickThrough } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.appDelegate?.updateOverlayFromSettings()
                self.observeClickThrough()
            }
        }
    }

    private func observeVisibilityMode() {
        withObservationTracking { _ = settings.overlayVisibilityMode } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.appDelegate?.refreshOverlay()
                self.observeVisibilityMode()
            }
        }
    }

    private func observeDebugLogging() {
        withObservationTracking { _ = settings.debugFlowLogging } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                DebugFlowLogger.shared.configure(enabled: self.settings.debugFlowLogging)
                self.observeDebugLogging()
            }
        }
    }

    private func checkUsageThresholds() {
        for provider in multiService.activeProviders {
            let usage = multiService.usageData(for: provider)
            guard usage.isAvailable else { continue }
            capacityAlertManager.check(
                usedPercentage: usage.usedPercentage,
                provider: provider,
                settings: settings
            )
        }
    }

    private func checkWeeklyUsageThresholds() {
        for provider in multiService.activeProviders {
            let usage = multiService.usageData(for: provider)
            guard usage.isAvailable,
                  let weeklyBucket = usage.rateLimitBuckets.first(where: {
                      $0.label.caseInsensitiveCompare("7d") == .orderedSame
                          || $0.label.caseInsensitiveCompare("1w") == .orderedSame
                  })
            else {
                continue
            }
            capacityAlertManager.checkWeekly(
                utilization: weeklyBucket.utilization,
                provider: provider,
                settings: settings
            )
        }
    }

    private func applyOverlayVisibility() {
        appDelegate?.applyOverlayVisibility(settings.showOverlay)
    }

    private func updateHotkey() {
        guard let appDelegate else { return }
        appDelegate.updateHotkey(settings: settings) { [weak appDelegate, weak settings] in
            guard let settings else { return }
            appDelegate?.toggleOverlay(settings: settings)
        }
    }

    private func configureHotkey() {
        guard let appDelegate else { return }
        appDelegate.setupHotkey(settings: settings) { [weak appDelegate, weak settings] in
            guard let settings else { return }
            appDelegate?.toggleOverlay(settings: settings)
        }
    }

    private func updateUsageVisibility() {
        appDelegate?.updateUsageVisibility()
    }

    private func recordActivationIfNeeded() {
        guard settings.firstUsageAt == nil, !multiService.availableProviders.isEmpty else { return }
        settings.firstUsageAt = Date()
        AppLogger.data.info("Recorded first usable provider activation")
    }
}
