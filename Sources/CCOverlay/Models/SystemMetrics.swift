import Foundation

enum SystemMemoryPressure: String, Equatable, Sendable {
    case normal
    case warning
    case critical

    var label: String {
        switch self {
        case .normal: "Normal"
        case .warning: "Pressure"
        case .critical: "Critical"
        }
    }
}

enum SystemThermalState: String, Equatable, Sendable {
    case nominal
    case fair
    case serious
    case critical

    var label: String {
        switch self {
        case .nominal: "Normal"
        case .fair: "Warm"
        case .serious: "Hot"
        case .critical: "Critical"
        }
    }
}

struct SystemMemoryMetrics: Equatable, Sendable {
    let usedBytes: UInt64
    let totalBytes: UInt64
    let swapUsedBytes: UInt64?
    let pressure: SystemMemoryPressure

    var usagePercentage: Double? {
        guard totalBytes > 0 else { return nil }
        return min(max(Double(usedBytes) / Double(totalBytes) * 100, 0), 100)
    }
}

struct SystemStorageMetrics: Equatable, Sendable {
    let availableBytes: Int64?
    let totalBytes: Int64?
}

struct SystemBatteryMetrics: Equatable, Sendable {
    let percentage: Double
    let isCharging: Bool
    let isCharged: Bool
    let isConnectedToPower: Bool

    init(
        percentage: Double,
        isCharging: Bool,
        isCharged: Bool = false,
        isConnectedToPower: Bool = false
    ) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.isConnectedToPower = isConnectedToPower
    }

    var statusLabel: String {
        if isCharging { return "charging" }
        if isCharged { return "charged" }
        if isConnectedToPower { return "plugged in" }
        return "on battery"
    }

    var systemImage: String {
        if isCharging { return "battery.100.bolt" }
        if isCharged || isConnectedToPower { return "battery.100" }
        return "battery.75"
    }
}

struct SystemNetworkMetrics: Equatable, Sendable {
    let receivedBytesPerSecond: Double?
    let sentBytesPerSecond: Double?
}

struct SystemMetricsSample: Identifiable, Equatable, Sendable {
    let timestamp: Date
    let cpuUsagePercentage: Double?
    let memory: SystemMemoryMetrics
    let network: SystemNetworkMetrics
    let storage: SystemStorageMetrics
    let battery: SystemBatteryMetrics?
    let thermalState: SystemThermalState

    var id: Date { timestamp }
}

enum SystemProcessSort: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case memory

    var id: String { rawValue }
    var label: String { self == .cpu ? "CPU" : "RAM" }
}

struct SystemProcessMetric: Identifiable, Equatable, Sendable {
    let pid: Int32
    let name: String
    let cpuUsagePercentage: Double
    let memoryBytes: UInt64

    var id: Int32 { pid }
}

struct RawSystemMetrics: Sendable {
    let timestamp: Date
    let cpuTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    let usedMemoryBytes: UInt64
    let totalMemoryBytes: UInt64
    let swapUsedBytes: UInt64?
    let receivedNetworkBytes: UInt64
    let sentNetworkBytes: UInt64
    let storage: SystemStorageMetrics
    let battery: SystemBatteryMetrics?
    let thermalState: SystemThermalState
}

protocol SystemMetricsCollecting: Sendable {
    func read() -> RawSystemMetrics
}

protocol SystemProcessMetricsCollecting: Sendable {
    func readTopProcesses() -> [SystemProcessMetric]
}
