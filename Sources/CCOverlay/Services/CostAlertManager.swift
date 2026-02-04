import AppKit
import Foundation

@Observable
@MainActor
final class CostAlertManager {
    private var lastAlertedThreshold: Double = 0
    private var lastWeeklyAlertedThreshold: Double = 0

    private static let thresholds: [Double] = [70, 90]

    func check(usedPercentage: Double, settings: AppSettings) {
        guard settings.costAlertEnabled else { return }

        for threshold in Self.thresholds {
            if usedPercentage >= threshold && lastAlertedThreshold < threshold {
                sendNotification(
                    title: "Claude Code Usage Alert",
                    body: "Session usage has reached \(Int(usedPercentage))% of your rate limit."
                )
                lastAlertedThreshold = threshold
            }
        }
    }

    func checkWeekly(utilization: Double, settings: AppSettings) {
        guard settings.costAlertEnabled else { return }

        for threshold in Self.thresholds {
            if utilization >= threshold && lastWeeklyAlertedThreshold < threshold {
                sendNotification(
                    title: "Claude Code Weekly Limit",
                    body: "Weekly usage has reached \(Int(utilization))% of your limit."
                )
                lastWeeklyAlertedThreshold = threshold
            }
        }
    }

    func resetThreshold() {
        lastAlertedThreshold = 0
        lastWeeklyAlertedThreshold = 0
    }

    private func sendNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}
