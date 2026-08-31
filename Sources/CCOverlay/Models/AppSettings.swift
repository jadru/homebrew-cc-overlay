import Foundation
import Observation

@Observable
final class AppSettings {
    @ObservationIgnored
    private let userDefaults: UserDefaults

    // MARK: - UserDefaults Keys

    private enum Key {
        static let showOverlay = "showOverlay"
        static let debugFlowLogging = "debugFlowLogging"
        static let refreshInterval = "refreshInterval"
        static let planTier = "planTier"
        static let customWeightedLimit = "customWeightedLimit"
        static let claudeOAuthEnabled = "claudeOAuthEnabled"
        static let alertWarningThreshold = "alertWarningThreshold"
        static let alertCriticalThreshold = "alertCriticalThreshold"
        static let launchAtLogin = "launchAtLogin"
        static let launchAtLoginRegistrationVersion = "launchAtLoginRegistrationVersion"
        static let costAlertEnabled = "costAlertEnabled"
        static let globalHotkeyEnabled = "globalHotkeyEnabled"
        static let legacyAlwaysExpanded = "pillAlwaysExpanded"
        static let pillClickThrough = "pillClickThrough"
        static let overlayPresentation = "overlayPresentation"
        static let overlayLayoutMigration = "overlayLayoutMigration"
        static let overlayVisibilityMode = "overlayVisibilityMode"
        static let systemMonitorMigration = "systemMonitorMigration"
        static let legacyOverlayPresentationMigration = "overlayPresentationMigration"
        static let legacyGardenBackground = "gardenBackground"
        static let legacyRetiredBackground = "companionBackground"
        static let legacyRetiredVisibility = "companionAlwaysVisible"
        static let autoUpdateEnabled = "autoUpdateEnabled"
        static let lastUpdateCheck = "lastUpdateCheck"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let firstLaunchAt = "firstLaunchAt"
        static let firstUsageAt = "firstUsageAt"
        static let preferredTerminal = "preferredTerminal"
        static let providerPriority = "providerPriority"
        static let fullResetPolicy = "fullResetPolicy"
    }

    // MARK: - General

    var showOverlay: Bool {
        get { access(keyPath: \.showOverlay); return userDefaults.bool(forKey: Key.showOverlay) }
        set { withMutation(keyPath: \.showOverlay) { userDefaults.set(newValue, forKey: Key.showOverlay) } }
    }

    var debugFlowLogging: Bool {
        get {
            access(keyPath: \.debugFlowLogging)
            return userDefaults.object(forKey: Key.debugFlowLogging) as? Bool ?? false
        }
        set {
            withMutation(keyPath: \.debugFlowLogging) {
                userDefaults.set(newValue, forKey: Key.debugFlowLogging)
            }
        }
    }

    var refreshInterval: TimeInterval {
        get {
            access(keyPath: \.refreshInterval)
            let val = userDefaults.double(forKey: Key.refreshInterval)
            return val == 0 ? 60.0 : val
        }
        set { withMutation(keyPath: \.refreshInterval) { userDefaults.set(newValue, forKey: Key.refreshInterval) } }
    }

    var planTier: PlanTier {
        get {
            access(keyPath: \.planTier)
            let raw = userDefaults.string(forKey: Key.planTier) ?? PlanTier.pro.rawValue
            return PlanTier(rawValue: raw) ?? .pro
        }
        set { withMutation(keyPath: \.planTier) { userDefaults.set(newValue.rawValue, forKey: Key.planTier) } }
    }

    var customWeightedLimit: Double {
        get {
            access(keyPath: \.customWeightedLimit)
            let val = userDefaults.double(forKey: Key.customWeightedLimit)
            return val == 0 ? 5_000_000 : val
        }
        set { withMutation(keyPath: \.customWeightedLimit) { userDefaults.set(newValue, forKey: Key.customWeightedLimit) } }
    }

    /// Claude OAuth access is opt-in because its Keychain item may require user authorization.
    var claudeOAuthEnabled: Bool {
        get { access(keyPath: \.claudeOAuthEnabled); return userDefaults.bool(forKey: Key.claudeOAuthEnabled) }
        set { withMutation(keyPath: \.claudeOAuthEnabled) { userDefaults.set(newValue, forKey: Key.claudeOAuthEnabled) } }
    }

    var launchAtLogin: Bool {
        get { access(keyPath: \.launchAtLogin); return userDefaults.bool(forKey: Key.launchAtLogin) }
        set { withMutation(keyPath: \.launchAtLogin) { userDefaults.set(newValue, forKey: Key.launchAtLogin) } }
    }

    var launchAtLoginRegistrationVersion: String? {
        get {
            access(keyPath: \AppSettings.launchAtLoginRegistrationVersion)
            return userDefaults.string(forKey: Key.launchAtLoginRegistrationVersion)
        }
        set {
            withMutation(keyPath: \AppSettings.launchAtLoginRegistrationVersion) {
                userDefaults.set(newValue, forKey: Key.launchAtLoginRegistrationVersion)
            }
        }
    }

    // MARK: - Alert Settings

    var costAlertEnabled: Bool {
        get { access(keyPath: \.costAlertEnabled); return userDefaults.bool(forKey: Key.costAlertEnabled) }
        set { withMutation(keyPath: \.costAlertEnabled) { userDefaults.set(newValue, forKey: Key.costAlertEnabled) } }
    }

    var alertWarningThreshold: Double {
        get {
            access(keyPath: \.alertWarningThreshold)
            let val = userDefaults.double(forKey: Key.alertWarningThreshold)
            return val == 0 ? AppConstants.defaultWarningThresholdPct : val
        }
        set {
            withMutation(keyPath: \.alertWarningThreshold) {
                let clamped = min(max(newValue, 1), 99)
                userDefaults.set(clamped, forKey: Key.alertWarningThreshold)
                if clamped >= alertCriticalThreshold {
                    userDefaults.set(min(clamped + 1, 100), forKey: Key.alertCriticalThreshold)
                }
            }
        }
    }

    var alertCriticalThreshold: Double {
        get {
            access(keyPath: \.alertCriticalThreshold)
            let val = userDefaults.double(forKey: Key.alertCriticalThreshold)
            return val == 0 ? AppConstants.defaultCriticalThresholdPct : val
        }
        set {
            withMutation(keyPath: \.alertCriticalThreshold) {
                let clamped = min(max(newValue, 1), 100)
                userDefaults.set(clamped, forKey: Key.alertCriticalThreshold)
                if clamped <= alertWarningThreshold {
                    userDefaults.set(max(clamped - 1, 1), forKey: Key.alertWarningThreshold)
                }
            }
        }
    }

    // MARK: - Hotkey Settings

    var globalHotkeyEnabled: Bool {
        get { access(keyPath: \.globalHotkeyEnabled); return userDefaults.bool(forKey: Key.globalHotkeyEnabled) }
        set { withMutation(keyPath: \.globalHotkeyEnabled) { userDefaults.set(newValue, forKey: Key.globalHotkeyEnabled) } }
    }

    // MARK: - Overlay Settings

    var overlayPresentation: OverlayPresentation {
        get {
            access(keyPath: \.overlayPresentation)
            let rawValue = userDefaults.string(forKey: Key.overlayPresentation)
            if rawValue == "systemMonitor" { return .horizontal }
            return OverlayPresentation(rawValue: rawValue ?? "") ?? .horizontal
        }
        set {
            withMutation(keyPath: \.overlayPresentation) {
                userDefaults.set(newValue.rawValue, forKey: Key.overlayPresentation)
            }
        }
    }

    var overlayVisibilityMode: OverlayVisibilityMode {
        get {
            access(keyPath: \.overlayVisibilityMode)
            let rawValue = userDefaults.string(forKey: Key.overlayVisibilityMode)
            return OverlayVisibilityMode(rawValue: rawValue ?? "") ?? .always
        }
        set {
            withMutation(keyPath: \.overlayVisibilityMode) {
                userDefaults.set(newValue.rawValue, forKey: Key.overlayVisibilityMode)
            }
        }
    }

    var pillClickThrough: Bool {
        get { access(keyPath: \.pillClickThrough); return userDefaults.bool(forKey: Key.pillClickThrough) }
        set { withMutation(keyPath: \.pillClickThrough) { userDefaults.set(newValue, forKey: Key.pillClickThrough) } }
    }

    /// Weighted cost limit for the current plan.
    var weightedCostLimit: Double {
        planTier == .custom ? customWeightedLimit : planTier.weightedCostLimit
    }

    // MARK: - Update Settings

    var autoUpdateEnabled: Bool {
        get {
            access(keyPath: \.autoUpdateEnabled)
            return userDefaults.object(forKey: Key.autoUpdateEnabled) as? Bool ?? true
        }
        set { withMutation(keyPath: \.autoUpdateEnabled) { userDefaults.set(newValue, forKey: Key.autoUpdateEnabled) } }
    }

    var lastUpdateCheck: Date? {
        get {
            access(keyPath: \.lastUpdateCheck)
            return userDefaults.object(forKey: Key.lastUpdateCheck) as? Date
        }
        set { withMutation(keyPath: \.lastUpdateCheck) { userDefaults.set(newValue, forKey: Key.lastUpdateCheck) } }
    }

    // MARK: - Activation and Onboarding

    var hasCompletedOnboarding: Bool {
        get {
            access(keyPath: \.hasCompletedOnboarding)
            return userDefaults.bool(forKey: Key.hasCompletedOnboarding)
        }
        set {
            withMutation(keyPath: \.hasCompletedOnboarding) {
                userDefaults.set(newValue, forKey: Key.hasCompletedOnboarding)
            }
        }
    }

    var firstLaunchAt: Date? {
        get {
            access(keyPath: \.firstLaunchAt)
            return userDefaults.object(forKey: Key.firstLaunchAt) as? Date
        }
        set {
            withMutation(keyPath: \.firstLaunchAt) {
                userDefaults.set(newValue, forKey: Key.firstLaunchAt)
            }
        }
    }

    var firstUsageAt: Date? {
        get {
            access(keyPath: \.firstUsageAt)
            return userDefaults.object(forKey: Key.firstUsageAt) as? Date
        }
        set {
            withMutation(keyPath: \.firstUsageAt) {
                userDefaults.set(newValue, forKey: Key.firstUsageAt)
            }
        }
    }

    var activationDuration: TimeInterval? {
        guard let firstLaunchAt, let firstUsageAt else { return nil }
        return max(firstUsageAt.timeIntervalSince(firstLaunchAt), 0)
    }

    var preferredTerminal: PreferredTerminal {
        get {
            access(keyPath: \.preferredTerminal)
            let rawValue = userDefaults.string(forKey: Key.preferredTerminal)
            return PreferredTerminal(rawValue: rawValue ?? "") ?? .terminal
        }
        set {
            withMutation(keyPath: \.preferredTerminal) {
                userDefaults.set(newValue.rawValue, forKey: Key.preferredTerminal)
            }
        }
    }

    var providerPriority: ProviderPriority {
        get {
            access(keyPath: \.providerPriority)
            let rawValue = userDefaults.string(forKey: Key.providerPriority)
            return ProviderPriority(rawValue: rawValue ?? "") ?? .codexFirst
        }
        set {
            withMutation(keyPath: \.providerPriority) {
                userDefaults.set(newValue.rawValue, forKey: Key.providerPriority)
            }
        }
    }

    var fullResetPolicy: FullResetPolicy {
        get {
            access(keyPath: \.fullResetPolicy)
            let rawValue = userDefaults.string(forKey: Key.fullResetPolicy)
            return FullResetPolicy(rawValue: rawValue ?? "") ?? .balanced
        }
        set {
            withMutation(keyPath: \.fullResetPolicy) {
                userDefaults.set(newValue.rawValue, forKey: Key.fullResetPolicy)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.userDefaults = defaults
        let isExistingInstall = defaults.object(forKey: Key.showOverlay) != nil
            || defaults.object(forKey: Key.lastUpdateCheck) != nil

        if defaults.object(forKey: Key.hasCompletedOnboarding) == nil {
            defaults.set(isExistingInstall, forKey: Key.hasCompletedOnboarding)
        }
        if defaults.object(forKey: Key.firstLaunchAt) == nil {
            defaults.set(Date(), forKey: Key.firstLaunchAt)
        }
        if defaults.string(forKey: Key.systemMonitorMigration) != "systemMonitorV1" {
            defaults.removeObject(forKey: "patchProgress.v1")
            defaults.removeObject(forKey: Key.legacyGardenBackground)
            defaults.removeObject(forKey: Key.legacyRetiredBackground)
            defaults.removeObject(forKey: Key.legacyRetiredVisibility)
            defaults.removeObject(forKey: Key.legacyOverlayPresentationMigration)
            defaults.set(OverlayPresentation.horizontal.rawValue, forKey: Key.overlayPresentation)
            defaults.set(OverlayVisibilityMode.always.rawValue, forKey: Key.overlayVisibilityMode)
            defaults.set("systemMonitorV1", forKey: Key.systemMonitorMigration)
        }
        if defaults.string(forKey: Key.overlayLayoutMigration) != "overlayLayoutV2" {
            let existingLayout = defaults.string(forKey: Key.overlayPresentation)
            if existingLayout == nil || existingLayout == "systemMonitor" {
                defaults.set(OverlayPresentation.horizontal.rawValue, forKey: Key.overlayPresentation)
            }
            defaults.set("overlayLayoutV2", forKey: Key.overlayLayoutMigration)
        }
        defaults.removeObject(forKey: Key.legacyAlwaysExpanded)

        userDefaults.register(defaults: [
            Key.showOverlay: true,
            Key.refreshInterval: 60.0,
            Key.debugFlowLogging: false,
            Key.claudeOAuthEnabled: false,
            Key.costAlertEnabled: true,
            Key.alertWarningThreshold: AppConstants.defaultWarningThresholdPct,
            Key.alertCriticalThreshold: AppConstants.defaultCriticalThresholdPct,
            Key.globalHotkeyEnabled: true,
            Key.pillClickThrough: false,
            Key.overlayPresentation: OverlayPresentation.horizontal.rawValue,
            Key.overlayVisibilityMode: OverlayVisibilityMode.always.rawValue,
            Key.autoUpdateEnabled: true,
            Key.hasCompletedOnboarding: false,
            Key.preferredTerminal: PreferredTerminal.terminal.rawValue,
            Key.providerPriority: ProviderPriority.codexFirst.rawValue,
            Key.fullResetPolicy: FullResetPolicy.balanced.rawValue,
        ])
    }
}
