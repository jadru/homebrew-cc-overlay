import Foundation
import Observation
import SwiftUI

@Observable
final class AppSettings {
    var showOverlay: Bool {
        get { access(keyPath: \.showOverlay); return UserDefaults.standard.bool(forKey: "showOverlay") }
        set { withMutation(keyPath: \.showOverlay) { UserDefaults.standard.set(newValue, forKey: "showOverlay") } }
    }

    var clickThrough: Bool {
        get { access(keyPath: \.clickThrough); return UserDefaults.standard.bool(forKey: "clickThrough") }
        set { withMutation(keyPath: \.clickThrough) { UserDefaults.standard.set(newValue, forKey: "clickThrough") } }
    }

    var overlayOpacity: Double {
        get {
            access(keyPath: \.overlayOpacity)
            let val = UserDefaults.standard.double(forKey: "overlayOpacity")
            return val == 0 ? 1.0 : val
        }
        set { withMutation(keyPath: \.overlayOpacity) { UserDefaults.standard.set(newValue, forKey: "overlayOpacity") } }
    }

    var refreshInterval: TimeInterval {
        get {
            access(keyPath: \.refreshInterval)
            let val = UserDefaults.standard.double(forKey: "refreshInterval")
            return val == 0 ? 60.0 : val
        }
        set { withMutation(keyPath: \.refreshInterval) { UserDefaults.standard.set(newValue, forKey: "refreshInterval") } }
    }

    var planTier: PlanTier {
        get {
            access(keyPath: \.planTier)
            let raw = UserDefaults.standard.string(forKey: "planTier") ?? PlanTier.pro.rawValue
            return PlanTier(rawValue: raw) ?? .pro
        }
        set { withMutation(keyPath: \.planTier) { UserDefaults.standard.set(newValue.rawValue, forKey: "planTier") } }
    }

    var billingMode: BillingMode {
        get {
            access(keyPath: \.billingMode)
            let raw = UserDefaults.standard.string(forKey: "billingMode") ?? BillingMode.subscription.rawValue
            return BillingMode(rawValue: raw) ?? .subscription
        }
        set { withMutation(keyPath: \.billingMode) { UserDefaults.standard.set(newValue.rawValue, forKey: "billingMode") } }
    }

    var customWeightedLimit: Double {
        get {
            access(keyPath: \.customWeightedLimit)
            let val = UserDefaults.standard.double(forKey: "customWeightedLimit")
            return val == 0 ? 5_000_000 : val
        }
        set { withMutation(keyPath: \.customWeightedLimit) { UserDefaults.standard.set(newValue, forKey: "customWeightedLimit") } }
    }

    var launchAtLogin: Bool {
        get { access(keyPath: \.launchAtLogin); return UserDefaults.standard.bool(forKey: "launchAtLogin") }
        set { withMutation(keyPath: \.launchAtLogin) { UserDefaults.standard.set(newValue, forKey: "launchAtLogin") } }
    }

    var glassTintIntensity: Double {
        get {
            access(keyPath: \.glassTintIntensity)
            let val = UserDefaults.standard.double(forKey: "glassTintIntensity")
            return val == 0 ? 0.25 : val
        }
        set { withMutation(keyPath: \.glassTintIntensity) { UserDefaults.standard.set(newValue, forKey: "glassTintIntensity") } }
    }

    // MARK: - Menu Bar Indicator

    var menuBarIndicatorStyle: MenuBarIndicatorStyle {
        get {
            access(keyPath: \.menuBarIndicatorStyle)
            let raw = UserDefaults.standard.string(forKey: "menuBarIndicatorStyle") ?? MenuBarIndicatorStyle.percentage.rawValue
            return MenuBarIndicatorStyle(rawValue: raw) ?? .percentage
        }
        set {
            withMutation(keyPath: \.menuBarIndicatorStyle) {
                UserDefaults.standard.set(newValue.rawValue, forKey: "menuBarIndicatorStyle")
            }
        }
    }

    // MARK: - Alert Settings

    var costAlertEnabled: Bool {
        get { access(keyPath: \.costAlertEnabled); return UserDefaults.standard.bool(forKey: "costAlertEnabled") }
        set { withMutation(keyPath: \.costAlertEnabled) { UserDefaults.standard.set(newValue, forKey: "costAlertEnabled") } }
    }

    // MARK: - Hotkey Settings

    var globalHotkeyEnabled: Bool {
        get { access(keyPath: \.globalHotkeyEnabled); return UserDefaults.standard.bool(forKey: "globalHotkeyEnabled") }
        set { withMutation(keyPath: \.globalHotkeyEnabled) { UserDefaults.standard.set(newValue, forKey: "globalHotkeyEnabled") } }
    }

    // MARK: - Focus Filter

    var overlayAutoHide: Bool {
        get { access(keyPath: \.overlayAutoHide); return UserDefaults.standard.bool(forKey: "overlayAutoHide") }
        set { withMutation(keyPath: \.overlayAutoHide) { UserDefaults.standard.set(newValue, forKey: "overlayAutoHide") } }
    }

    /// Weighted cost limit for the current plan.
    var weightedCostLimit: Double {
        planTier == .custom ? customWeightedLimit : planTier.weightedCostLimit
    }

    init() {
        // Register defaults
        UserDefaults.standard.register(defaults: [
            "showOverlay": true,
            "overlayOpacity": 1.0,
            "refreshInterval": 60.0,
            "glassTintIntensity": 0.25,
            "costAlertEnabled": true,
            "globalHotkeyEnabled": true,
            "overlayAutoHide": true,
            "menuBarIndicatorStyle": MenuBarIndicatorStyle.percentage.rawValue,
        ])
    }
}
