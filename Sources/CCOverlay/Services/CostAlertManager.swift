import AppKit
import Foundation

@Observable
@MainActor
final class CostAlertManager {
    private var lastAlertedThreshold: Double = 0

    private static let thresholds: [Double] = [70, 90]

    func check(usedPercentage: Double, settings: AppSettings) {
        guard settings.costAlertEnabled else { return }

        for threshold in Self.thresholds {
            if usedPercentage >= threshold && lastAlertedThreshold < threshold {
                sendNotification(threshold: threshold, used: usedPercentage)
                lastAlertedThreshold = threshold
            }
        }
    }

    func resetThreshold() {
        lastAlertedThreshold = 0
    }

    private func sendNotification(threshold: Double, used: Double) {
        let notification = NSUserNotification()
        notification.title = "Claude Code Usage Alert"
        notification.informativeText = "Usage has reached \(Int(used))% of your rate limit."
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}
