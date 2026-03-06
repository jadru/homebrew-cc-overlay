import Foundation
import Observation
import SwiftUI

@Observable
final class AppSettings {

    // MARK: - UserDefaults Keys

    private enum Key {
        static let showOverlay = "showOverlay"
        static let debugFlowLogging = "debugFlowLogging"
        static let refreshInterval = "refreshInterval"
        static let planTier = "planTier"
        static let customWeightedLimit = "customWeightedLimit"
        static let alertWarningThreshold = "alertWarningThreshold"
        static let alertCriticalThreshold = "alertCriticalThreshold"
        static let launchAtLogin = "launchAtLogin"
        static let menuBarIndicatorStyle = "menuBarIndicatorStyle"
        static let costAlertEnabled = "costAlertEnabled"
        static let globalHotkeyEnabled = "globalHotkeyEnabled"
        static let pillAlwaysExpanded = "pillAlwaysExpanded"
        static let pillShowDailyCost = "pillShowDailyCost"
        static let pillOpacity = "pillOpacity"
        static let pillClickThrough = "pillClickThrough"
        static let autoUpdateEnabled = "autoUpdateEnabled"
        static let lastUpdateCheck = "lastUpdateCheck"
        static let claudeCodeEnabled = "claudeCodeEnabled"
        static let codexEnabled = "codexEnabled"
        static let geminiEnabled = "geminiEnabled"
        static let pausedProviders = "pausedProviders"
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

    var launchAtLogin: Bool {
        get { access(keyPath: \.launchAtLogin); return UserDefaults.standard.bool(forKey: Key.launchAtLogin) }
        set { withMutation(keyPath: \.launchAtLogin) { UserDefaults.standard.set(newValue, forKey: Key.launchAtLogin) } }
    }

    // MARK: - Menu Bar Indicator

    var menuBarIndicatorStyle: MenuBarIndicatorStyle {
        get {
            access(keyPath: \.menuBarIndicatorStyle)
            let raw = UserDefaults.standard.string(forKey: Key.menuBarIndicatorStyle) ?? MenuBarIndicatorStyle.percentage.rawValue
            return MenuBarIndicatorStyle(rawValue: raw) ?? .percentage
        }
        set {
            withMutation(keyPath: \.menuBarIndicatorStyle) {
                UserDefaults.standard.set(newValue.rawValue, forKey: Key.menuBarIndicatorStyle)
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

    var pillShowDailyCost: Bool {
        get {
            access(keyPath: \.pillShowDailyCost)
            return UserDefaults.standard.object(forKey: Key.pillShowDailyCost) as? Bool ?? true
        }
        set { withMutation(keyPath: \.pillShowDailyCost) { UserDefaults.standard.set(newValue, forKey: Key.pillShowDailyCost) } }
    }

    var pillOpacity: Double {
        get {
            access(keyPath: \.pillOpacity)
            let val = UserDefaults.standard.double(forKey: Key.pillOpacity)
            return val == 0 ? 1.0 : val
        }
        set { withMutation(keyPath: \.pillOpacity) { UserDefaults.standard.set(newValue, forKey: Key.pillOpacity) } }
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

    // MARK: - Provider Settings

    var claudeCodeEnabled: Bool {
        get {
            access(keyPath: \.claudeCodeEnabled)
            return UserDefaults.standard.object(forKey: Key.claudeCodeEnabled) as? Bool ?? true
        }
        set { withMutation(keyPath: \.claudeCodeEnabled) { UserDefaults.standard.set(newValue, forKey: Key.claudeCodeEnabled) } }
    }

    var codexEnabled: Bool {
        get {
            access(keyPath: \.codexEnabled)
            return UserDefaults.standard.object(forKey: Key.codexEnabled) as? Bool ?? true
        }
        set { withMutation(keyPath: \.codexEnabled) { UserDefaults.standard.set(newValue, forKey: Key.codexEnabled) } }
    }

    // MARK: - Gemini Settings

    var geminiEnabled: Bool {
        get {
            access(keyPath: \.geminiEnabled)
            return UserDefaults.standard.object(forKey: Key.geminiEnabled) as? Bool ?? true
        }
        set { withMutation(keyPath: \.geminiEnabled) { UserDefaults.standard.set(newValue, forKey: Key.geminiEnabled) } }
    }

    // MARK: - Pause Controls

    var pausedProviders: Set<CLIProvider> {
        get {
            access(keyPath: \.pausedProviders)
            let raw = UserDefaults.standard.stringArray(forKey: Key.pausedProviders) ?? []
            return Set(raw.compactMap(CLIProvider.init(rawValue:)))
        }
        set {
            withMutation(keyPath: \.pausedProviders) {
                UserDefaults.standard.set(
                    Array(newValue).map(\.rawValue),
                    forKey: Key.pausedProviders
                )
            }
        }
    }

    func isProviderPaused(_ provider: CLIProvider) -> Bool {
        pausedProviders.contains(provider)
    }

    func setProviderPaused(_ provider: CLIProvider, paused: Bool) {
        var updated = pausedProviders
        if paused {
            updated.insert(provider)
        } else {
            updated.remove(provider)
        }
        pausedProviders = updated
    }

    func isEnabled(_ provider: CLIProvider) -> Bool {
        switch provider {
        case .claudeCode: return claudeCodeEnabled
        case .codex: return codexEnabled
        case .gemini: return geminiEnabled
        }
    }

    init() {
        UserDefaults.standard.register(defaults: [
            Key.showOverlay: true,
        Key.refreshInterval: 60.0,
            Key.debugFlowLogging: false,
            Key.costAlertEnabled: true,
            Key.alertWarningThreshold: AppConstants.defaultWarningThresholdPct,
            Key.alertCriticalThreshold: AppConstants.defaultCriticalThresholdPct,
            Key.globalHotkeyEnabled: true,
            Key.menuBarIndicatorStyle: MenuBarIndicatorStyle.percentage.rawValue,
            Key.pillAlwaysExpanded: false,
            Key.pillShowDailyCost: true,
            Key.pillOpacity: 1.0,
            Key.pillClickThrough: false,
            Key.autoUpdateEnabled: true,
            Key.claudeCodeEnabled: true,
            Key.codexEnabled: true,
            Key.geminiEnabled: true,
            Key.pausedProviders: [],
        ])
    }
}
