import Foundation
import Observation
@preconcurrency import UserNotifications

protocol CapacityNotificationCenter {
    func getAuthorizationStatus(completion: @escaping @Sendable (UNAuthorizationStatus) -> Void)
    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void)
    func addNotificationRequest(
        _ request: UNNotificationRequest,
        completion: @escaping @Sendable (Error?) -> Void
    )
}

extension UNUserNotificationCenter: CapacityNotificationCenter {
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
final class CapacityAlertManager {
    private var lastAlertedThresholds: [CLIProvider: Double] = [:]
    private var lastWeeklyAlertedThresholds: [CLIProvider: Double] = [:]
    private var highestMemoryPressureAlerted: SystemMemoryPressure = .normal
    private var highestThermalAlerted: SystemThermalState = .nominal
    @ObservationIgnored
    private let notificationCenterProvider: () -> CapacityNotificationCenter
    @ObservationIgnored
    private var cachedNotificationCenter: CapacityNotificationCenter?

    init(notificationCenter: CapacityNotificationCenter) {
        self.notificationCenterProvider = { notificationCenter }
    }

    init(notificationCenterProvider: @escaping () -> CapacityNotificationCenter = { UNUserNotificationCenter.current() }) {
        self.notificationCenterProvider = notificationCenterProvider
    }

    func check(
        usedPercentage: Double,
        provider: CLIProvider = .claudeCode,
        settings: AppSettings
    ) {
        guard settings.costAlertEnabled else {
            DebugFlowLogger.shared.log(
                stage: .alert,
                message: "check.skipped",
                details: ["reason": "disabled"]
            )
            return
        }

        let lastAlertedThreshold = lastAlertedThresholds[provider, default: 0]
        for threshold in thresholds(from: settings) {
            if usedPercentage >= threshold && lastAlertedThreshold < threshold {
                sendNotification(
                    title: "\(provider.rawValue) Usage Alert",
                    body: "Usage has reached \(Int(usedPercentage))% of your rate limit."
                )
                DebugFlowLogger.shared.log(
                    stage: .alert,
                    provider: provider,
                    message: "threshold.crossed",
                    details: ["type": "session", "value": "\(usedPercentage)", "threshold": "\(threshold)"]
                )
                lastAlertedThresholds[provider] = threshold
            }
        }
    }

    func checkWeekly(
        utilization: Double,
        provider: CLIProvider = .claudeCode,
        settings: AppSettings
    ) {
        guard settings.costAlertEnabled else {
            DebugFlowLogger.shared.log(
                stage: .alert,
                message: "checkWeekly.skipped",
                details: ["reason": "disabled"]
            )
            return
        }

        let lastWeeklyAlertedThreshold = lastWeeklyAlertedThresholds[provider, default: 0]
        for threshold in thresholds(from: settings) {
            if utilization >= threshold && lastWeeklyAlertedThreshold < threshold {
                sendNotification(
                    title: "\(provider.rawValue) Weekly Limit",
                    body: "Weekly usage has reached \(Int(utilization))% of your limit."
                )
                DebugFlowLogger.shared.log(
                    stage: .alert,
                    provider: provider,
                    message: "threshold.crossed",
                    details: ["type": "weekly", "value": "\(utilization)", "threshold": "\(threshold)"]
                )
                lastWeeklyAlertedThresholds[provider] = threshold
            }
        }
    }

    func resetThreshold() {
        lastAlertedThresholds.removeAll()
        lastWeeklyAlertedThresholds.removeAll()
    }

    func checkSystem(sample: SystemMetricsSample?) {
        guard let sample else { return }

        let memorySeverity: Int
        switch sample.memory.pressure {
        case .normal: memorySeverity = 0
        case .warning: memorySeverity = 1
        case .critical: memorySeverity = 2
        }
        let alertedMemorySeverity: Int
        switch highestMemoryPressureAlerted {
        case .normal: alertedMemorySeverity = 0
        case .warning: alertedMemorySeverity = 1
        case .critical: alertedMemorySeverity = 2
        }
        if memorySeverity == 0 {
            highestMemoryPressureAlerted = .normal
        } else if memorySeverity > alertedMemorySeverity {
            highestMemoryPressureAlerted = sample.memory.pressure
            let state = sample.memory.pressure == .critical ? "critical" : "elevated"
            sendNotification(
                title: "Memory pressure is \(state)",
                body: "macOS is under memory pressure. Close or pause a memory-intensive process."
            )
        }

        let severity: Int
        switch sample.thermalState {
        case .nominal, .fair: severity = 0
        case .serious: severity = 1
        case .critical: severity = 2
        }
        let alertedSeverity: Int
        switch highestThermalAlerted {
        case .nominal, .fair: alertedSeverity = 0
        case .serious: alertedSeverity = 1
        case .critical: alertedSeverity = 2
        }
        if severity == 0 {
            highestThermalAlerted = .nominal
        } else if severity > alertedSeverity {
            highestThermalAlerted = sample.thermalState
            sendNotification(
                title: "Mac thermal state is \(sample.thermalState.label.lowercased())",
                body: "macOS may reduce performance while the device cools down."
            )
        }
    }

    func scheduleResetNotification(at resetAt: Date, provider: CLIProvider?) {
        let interval = resetAt.timeIntervalSinceNow
        guard interval > 1 else { return }

        let providerName = provider?.rawValue ?? "Provider"
        sendNotification(
            title: "\(providerName) headroom is back",
            body: "The active usage window has reset. Recheck CC-Overlay before starting the next run.",
            scheduledAt: resetAt
        )
    }

    private func thresholds(from settings: AppSettings) -> [Double] {
        let warning = min(max(settings.alertWarningThreshold, 1), 100)
        let critical = min(max(settings.alertCriticalThreshold, 1), 100)
        return Array(Set([warning, critical])).sorted()
    }

    private func sendNotification(
        title: String,
        body: String,
        scheduledAt: Date? = nil
    ) {
        let center = notificationCenter()
        center.getAuthorizationStatus { status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard status == .authorized || status == .provisional else {
                    if status == .notDetermined {
                        self.notificationCenter().requestAuthorization { granted in
                            guard granted else { return }
                            Task { @MainActor [weak self] in
                                self?.deliverNotification(title: title, body: body, scheduledAt: scheduledAt)
                            }
                        }
                    }
                    return
                }
                self.deliverNotification(title: title, body: body, scheduledAt: scheduledAt)
            }
        }
    }

    private func deliverNotification(
        title: String,
        body: String,
        scheduledAt: Date? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = scheduledAt.map {
            UNTimeIntervalNotificationTrigger(
                timeInterval: max($0.timeIntervalSinceNow, 1),
                repeats: false
            )
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
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

    private func notificationCenter() -> CapacityNotificationCenter {
        if let cachedNotificationCenter {
            return cachedNotificationCenter
        }

        let center = notificationCenterProvider()
        cachedNotificationCenter = center
        return center
    }
}
