import Foundation
import Observation

@Observable
final class AppSettings {

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
        static let pillAlwaysExpanded = "pillAlwaysExpanded"
        static let pillClickThrough = "pillClickThrough"
        static let autoUpdateEnabled = "autoUpdateEnabled"
        static let lastUpdateCheck = "lastUpdateCheck"
    }

    // MARK: - General

    var showOverlay: Bool {
        get { access(keyPath: \.showOverlay); return UserDefaults.standard.bool(forKey: Key.showOverlay) }
        set { withMutation(keyPath: \.showOverlay) { UserDefaults.standard.set(newValue, forKey: Key.showOverlay) } }
    }

    var debugFlowLogging: Bool {
        get {
            access(keyPath: \.debugFlowLogging)
            return UserDefaults.standard.object(forKey: Key.debugFlowLogging) as? Bool ?? false
        }
        set {
            withMutation(keyPath: \.debugFlowLogging) {
                UserDefaults.standard.set(newValue, forKey: Key.debugFlowLogging)
            }
        }
    }

    var refreshInterval: TimeInterval {
        get {
            access(keyPath: \.refreshInterval)
            let val = UserDefaults.standard.double(forKey: Key.refreshInterval)
            return val == 0 ? 60.0 : val
        }
        set { withMutation(keyPath: \.refreshInterval) { UserDefaults.standard.set(newValue, forKey: Key.refreshInterval) } }
    }

    var planTier: PlanTier {
        get {
            access(keyPath: \.planTier)
            let raw = UserDefaults.standard.string(forKey: Key.planTier) ?? PlanTier.pro.rawValue
            return PlanTier(rawValue: raw) ?? .pro
        }
        set { withMutation(keyPath: \.planTier) { UserDefaults.standard.set(newValue.rawValue, forKey: Key.planTier) } }
    }

    var customWeightedLimit: Double {
        get {
            access(keyPath: \.customWeightedLimit)
            let val = UserDefaults.standard.double(forKey: Key.customWeightedLimit)
            return val == 0 ? 5_000_000 : val
        }
        set { withMutation(keyPath: \.customWeightedLimit) { UserDefaults.standard.set(newValue, forKey: Key.customWeightedLimit) } }
    }

    /// Claude OAuth access is opt-in because its Keychain item may require user authorization.
    var claudeOAuthEnabled: Bool {
        get { access(keyPath: \.claudeOAuthEnabled); return UserDefaults.standard.bool(forKey: Key.claudeOAuthEnabled) }
        set { withMutation(keyPath: \.claudeOAuthEnabled) { UserDefaults.standard.set(newValue, forKey: Key.claudeOAuthEnabled) } }
    }

    var launchAtLogin: Bool {
        get { access(keyPath: \.launchAtLogin); return UserDefaults.standard.bool(forKey: Key.launchAtLogin) }
        set { withMutation(keyPath: \.launchAtLogin) { UserDefaults.standard.set(newValue, forKey: Key.launchAtLogin) } }
    }

    var launchAtLoginRegistrationVersion: String? {
        get {
            access(keyPath: \AppSettings.launchAtLoginRegistrationVersion)
            return UserDefaults.standard.string(forKey: Key.launchAtLoginRegistrationVersion)
        }
        set {
            withMutation(keyPath: \AppSettings.launchAtLoginRegistrationVersion) {
                UserDefaults.standard.set(newValue, forKey: Key.launchAtLoginRegistrationVersion)
            }
        }
    }

    // MARK: - Alert Settings

    var costAlertEnabled: Bool {
        get { access(keyPath: \.costAlertEnabled); return UserDefaults.standard.bool(forKey: Key.costAlertEnabled) }
        set { withMutation(keyPath: \.costAlertEnabled) { UserDefaults.standard.set(newValue, forKey: Key.costAlertEnabled) } }
    }

    var alertWarningThreshold: Double {
        get {
            access(keyPath: \.alertWarningThreshold)
            let val = UserDefaults.standard.double(forKey: Key.alertWarningThreshold)
            return val == 0 ? AppConstants.defaultWarningThresholdPct : val
        }
        set {
            withMutation(keyPath: \.alertWarningThreshold) {
                let clamped = min(max(newValue, 1), 99)
                UserDefaults.standard.set(clamped, forKey: Key.alertWarningThreshold)
                if clamped >= alertCriticalThreshold {
                    UserDefaults.standard.set(min(clamped + 1, 100), forKey: Key.alertCriticalThreshold)
                }
            }
        }
    }

    var alertCriticalThreshold: Double {
        get {
            access(keyPath: \.alertCriticalThreshold)
            let val = UserDefaults.standard.double(forKey: Key.alertCriticalThreshold)
            return val == 0 ? AppConstants.defaultCriticalThresholdPct : val
        }
        set {
            withMutation(keyPath: \.alertCriticalThreshold) {
                let clamped = min(max(newValue, 1), 100)
                UserDefaults.standard.set(clamped, forKey: Key.alertCriticalThreshold)
                if clamped <= alertWarningThreshold {
                    UserDefaults.standard.set(max(clamped - 1, 1), forKey: Key.alertWarningThreshold)
                }
            }
        }
    }

    // MARK: - Hotkey Settings

    var globalHotkeyEnabled: Bool {
        get { access(keyPath: \.globalHotkeyEnabled); return UserDefaults.standard.bool(forKey: Key.globalHotkeyEnabled) }
        set { withMutation(keyPath: \.globalHotkeyEnabled) { UserDefaults.standard.set(newValue, forKey: Key.globalHotkeyEnabled) } }
    }

    // MARK: - Overlay (Pill) Settings

    var pillAlwaysExpanded: Bool {
        get { access(keyPath: \.pillAlwaysExpanded); return UserDefaults.standard.bool(forKey: Key.pillAlwaysExpanded) }
        set { withMutation(keyPath: \.pillAlwaysExpanded) { UserDefaults.standard.set(newValue, forKey: Key.pillAlwaysExpanded) } }
    }

    var pillClickThrough: Bool {
        get { access(keyPath: \.pillClickThrough); return UserDefaults.standard.bool(forKey: Key.pillClickThrough) }
        set { withMutation(keyPath: \.pillClickThrough) { UserDefaults.standard.set(newValue, forKey: Key.pillClickThrough) } }
    }

    /// Weighted cost limit for the current plan.
    var weightedCostLimit: Double {
        planTier == .custom ? customWeightedLimit : planTier.weightedCostLimit
    }

    // MARK: - Update Settings

    var autoUpdateEnabled: Bool {
        get {
            access(keyPath: \.autoUpdateEnabled)
            return UserDefaults.standard.object(forKey: Key.autoUpdateEnabled) as? Bool ?? true
        }
        set { withMutation(keyPath: \.autoUpdateEnabled) { UserDefaults.standard.set(newValue, forKey: Key.autoUpdateEnabled) } }
    }

    var lastUpdateCheck: Date? {
        get {
            access(keyPath: \.lastUpdateCheck)
            return UserDefaults.standard.object(forKey: Key.lastUpdateCheck) as? Date
        }
        set { withMutation(keyPath: \.lastUpdateCheck) { UserDefaults.standard.set(newValue, forKey: Key.lastUpdateCheck) } }
    }

    init() {
        UserDefaults.standard.register(defaults: [
            Key.showOverlay: true,
            Key.refreshInterval: 60.0,
            Key.debugFlowLogging: false,
            Key.claudeOAuthEnabled: false,
            Key.costAlertEnabled: true,
            Key.alertWarningThreshold: AppConstants.defaultWarningThresholdPct,
            Key.alertCriticalThreshold: AppConstants.defaultCriticalThresholdPct,
            Key.globalHotkeyEnabled: true,
            Key.pillAlwaysExpanded: false,
            Key.pillClickThrough: false,
            Key.autoUpdateEnabled: true,
        ])
    }
}
