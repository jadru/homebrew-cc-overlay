import Foundation
import Observation
@preconcurrency import UserNotifications

protocol CostNotificationCenter {
    func getAuthorizationStatus(completion: @escaping @Sendable (UNAuthorizationStatus) -> Void)
    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void)
    func addNotificationRequest(
        _ request: UNNotificationRequest,
        completion: @escaping @Sendable (Error?) -> Void
    )
}

extension UNUserNotificationCenter: CostNotificationCenter {
    func getAuthorizationStatus(completion: @escaping @Sendable (UNAuthorizationStatus) -> Void) {
        getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        requestAuthorization(options: [.alert, .sound]) { granted, _ in
            completion(granted)
        }
    }

    func addNotificationRequest(
        _ request: UNNotificationRequest,
        completion: @escaping @Sendable (Error?) -> Void
    ) {
        add(request, withCompletionHandler: completion)
    }
}

@Observable
@MainActor
final class CostAlertManager {
    private var lastAlertedThreshold: Double = 0
    private var lastWeeklyAlertedThreshold: Double = 0
    @ObservationIgnored
    private let notificationCenterProvider: () -> CostNotificationCenter
    @ObservationIgnored
    private var cachedNotificationCenter: CostNotificationCenter?

    init(notificationCenter: CostNotificationCenter) {
        self.notificationCenterProvider = { notificationCenter }
    }

    init(notificationCenterProvider: @escaping () -> CostNotificationCenter = { UNUserNotificationCenter.current() }) {
        self.notificationCenterProvider = notificationCenterProvider
    }

    func check(usedPercentage: Double, settings: AppSettings) {
        guard settings.costAlertEnabled else {
            DebugFlowLogger.shared.log(
                stage: .alert,
                message: "check.skipped",
                details: ["reason": "disabled"]
            )
            return
        }

        for threshold in thresholds(from: settings) {
            if usedPercentage >= threshold && lastAlertedThreshold < threshold {
                sendNotification(
                    title: "Claude Code Usage Alert",
                    body: "Session usage has reached \(Int(usedPercentage))% of your rate limit."
                )
                DebugFlowLogger.shared.log(
                    stage: .alert,
                    message: "threshold.crossed",
                    details: ["type": "session", "value": "\(usedPercentage)", "threshold": "\(threshold)"]
                )
                lastAlertedThreshold = threshold
            }
        }
    }

    func checkWeekly(utilization: Double, settings: AppSettings) {
        guard settings.costAlertEnabled else {
            DebugFlowLogger.shared.log(
                stage: .alert,
                message: "checkWeekly.skipped",
                details: ["reason": "disabled"]
            )
            return
        }

        for threshold in thresholds(from: settings) {
            if utilization >= threshold && lastWeeklyAlertedThreshold < threshold {
                sendNotification(
                    title: "Claude Code Weekly Limit",
                    body: "Weekly usage has reached \(Int(utilization))% of your limit."
                )
                DebugFlowLogger.shared.log(
                    stage: .alert,
                    message: "threshold.crossed",
                    details: ["type": "weekly", "value": "\(utilization)", "threshold": "\(threshold)"]
                )
                lastWeeklyAlertedThreshold = threshold
            }
        }
    }

    func resetThreshold() {
        lastAlertedThreshold = 0
        lastWeeklyAlertedThreshold = 0
    }

    private func thresholds(from settings: AppSettings) -> [Double] {
        let warning = min(max(settings.alertWarningThreshold, 1), 100)
        let critical = min(max(settings.alertCriticalThreshold, 1), 100)
        return Array(Set([warning, critical])).sorted()
    }

    private func sendNotification(title: String, body: String) {
        let center = notificationCenter()
        center.getAuthorizationStatus { status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard status == .authorized || status == .provisional else {
                    if status == .notDetermined {
                        self.notificationCenter().requestAuthorization { granted in
                            guard granted else { return }
                            Task { @MainActor [weak self] in
                                self?.deliverNotification(title: title, body: body)
                            }
                        }
                    }
                    return
                }
                self.deliverNotification(title: title, body: body)
            }
        }
    }

    private func deliverNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        notificationCenter().addNotificationRequest(request) { error in
            Task { @MainActor in
                if let error {
                    AppLogger.data.error("Failed to deliver notification: \(error.localizedDescription)")
                    DebugFlowLogger.shared.log(
                        stage: .alert,
                        message: "notification.failed",
                        details: ["error": error.localizedDescription]
                    )
                } else {
                    DebugFlowLogger.shared.log(
                        stage: .alert,
                        message: "notification.sent"
                    )
                }
            }
        }
    }

    private func notificationCenter() -> CostNotificationCenter {
        if let cachedNotificationCenter {
            return cachedNotificationCenter
        }

        let center = notificationCenterProvider()
        cachedNotificationCenter = center
        return center
    }
}
