import Darwin
import Foundation
import IOKit.ps
import Observation

struct MacSystemMetricsCollector: SystemMetricsCollecting {
    func read() -> RawSystemMetrics {
        let network = networkTotals()
        return RawSystemMetrics(
            timestamp: Date(),
            cpuTicks: cpuTicks(),
            usedMemoryBytes: usedMemoryBytes(),
            totalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            swapUsedBytes: swapUsedBytes(),
            receivedNetworkBytes: network.received,
            sentNetworkBytes: network.sent,
            storage: storageMetrics(),
            battery: batteryMetrics(),
            thermalState: thermalState()
        )
    }

    private func cpuTicks() -> (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)? {
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )
        guard result == KERN_SUCCESS, let processorInfo else { return nil }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: processorInfo)),
                vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let values = UnsafeBufferPointer(start: processorInfo, count: Int(processorInfoCount))
        var user: UInt64 = 0
        var system: UInt64 = 0
        var idle: UInt64 = 0
        var nice: UInt64 = 0
        for processorIndex in 0..<Int(processorCount) {
            let index = processorIndex * Int(CPU_STATE_MAX)
            guard index + Int(CPU_STATE_NICE) < values.count else { break }
            user += UInt64(values[index + Int(CPU_STATE_USER)])
            system += UInt64(values[index + Int(CPU_STATE_SYSTEM)])
            idle += UInt64(values[index + Int(CPU_STATE_IDLE)])
            nice += UInt64(values[index + Int(CPU_STATE_NICE)])
        }
        return (user, system, idle, nice)
    }

    private func usedMemoryBytes() -> UInt64 {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return 0
        }
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return 0 }
        let pages = UInt64(info.wire_count) + UInt64(info.active_count) + UInt64(info.inactive_count) + UInt64(info.compressor_page_count)
        return pages * UInt64(pageSize)
    }

    private func swapUsedBytes() -> UInt64? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return nil }
        return usage.xsu_used
    }

    private func networkTotals() -> (received: UInt64, sent: UInt64) {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let head else { return (0, 0) }
        defer { freeifaddrs(head) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var current: UnsafeMutablePointer<ifaddrs>? = head
        while let interface = current {
            defer { current = interface.pointee.ifa_next }
            let flags = Int32(interface.pointee.ifa_flags)
            guard flags & IFF_UP != 0,
                  flags & IFF_LOOPBACK == 0,
                  let data = interface.pointee.ifa_data
            else { continue }
            let statistics = data.assumingMemoryBound(to: if_data.self).pointee
            received += UInt64(statistics.ifi_ibytes)
            sent += UInt64(statistics.ifi_obytes)
        }
        return (received, sent)
    }

    private func storageMetrics() -> SystemStorageMetrics {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityKey, .volumeTotalCapacityKey]
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys)
        return SystemStorageMetrics(
            availableBytes: values?.volumeAvailableCapacity.map { Int64($0) },
            totalBytes: values?.volumeTotalCapacity.map { Int64($0) }
        )
    }

    private func batteryMetrics() -> SystemBatteryMetrics? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSIsPresentKey] as? Bool != false,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int,
                  maximum > 0
            else { continue }
            let powerState = description[kIOPSPowerSourceStateKey] as? String
            return SystemBatteryMetrics(
                percentage: Double(current) / Double(maximum) * 100,
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isCharged: description[kIOPSIsChargedKey] as? Bool ?? false,
                isConnectedToPower: powerState == kIOPSACPowerValue
            )
        }
        return nil
    }

    private func thermalState() -> SystemThermalState {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .fair
        }
    }
}

struct PSProcessMetricsCollector: SystemProcessMetricsCollecting {
    func readTopProcesses() -> [SystemProcessMetric] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Ao", "pid=,pcpu=,rss=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8)
        else { return [] }

        return output.split(separator: "\n").compactMap { line in
            let fields = line.split(maxSplits: 3, whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 4,
                  let pid = Int32(fields[0]),
                  let cpu = Double(fields[1]),
                  let residentKilobytes = UInt64(fields[2])
            else { return nil }
            let command = String(fields[3])
            return SystemProcessMetric(
                pid: pid,
                name: URL(fileURLWithPath: command).lastPathComponent,
                cpuUsagePercentage: max(cpu, 0),
                memoryBytes: residentKilobytes * 1_024
            )
        }
    }
}

@Observable
@MainActor
final class SystemMetricsService {
    private(set) var currentSample: SystemMetricsSample?
    private(set) var recentSamples: [SystemMetricsSample] = []
    private(set) var topProcesses: [SystemProcessMetric] = []
    private(set) var lastRefresh: Date?
    private(set) var isMonitoring = false

    private let collector: any SystemMetricsCollecting
    private let processCollector: any SystemProcessMetricsCollecting
    private let isLowPowerModeEnabled: @Sendable () -> Bool
    private var timer: Timer?
    private var rawPrevious: RawSystemMetrics?
    private var processTask: Task<Void, Never>?
    private var lastProcessRefresh: Date?
    private var processMonitoringEnabled = false
    private var memoryPressure: SystemMemoryPressure = .normal
    private var memoryPressureSource: (any DispatchSourceMemoryPressure)?
    private var thermalObserver: NSObjectProtocol?

    init(
        collector: any SystemMetricsCollecting = MacSystemMetricsCollector(),
        processCollector: any SystemProcessMetricsCollecting = PSProcessMetricsCollector(),
        isLowPowerModeEnabled: @escaping @Sendable () -> Bool = { ProcessInfo.processInfo.isLowPowerModeEnabled }
    ) {
        self.collector = collector
        self.processCollector = processCollector
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
    }

    func startMonitoring() {
        guard timer == nil else { return }
        isMonitoring = true
        installSystemObservers()
        refresh()
        scheduleTimer()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        processTask?.cancel()
        processTask = nil
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        if let thermalObserver {
            NotificationCenter.default.removeObserver(thermalObserver)
            self.thermalObserver = nil
        }
        isMonitoring = false
    }

    func setProcessMonitoringEnabled(_ enabled: Bool) {
        processMonitoringEnabled = enabled
        guard enabled else { return }
        refreshProcessesIfNeeded(force: true)
    }

    func refresh() {
        let raw = collector.read()
        let sample = Self.makeSample(raw: raw, previous: rawPrevious, memoryPressure: memoryPressure)
        rawPrevious = raw
        currentSample = sample
        lastRefresh = raw.timestamp
        recentSamples = Self.trimmedSamples(recentSamples + [sample], at: raw.timestamp)
        if processMonitoringEnabled { refreshProcessesIfNeeded() }
    }

    func samplingInterval() -> TimeInterval {
        isLowPowerModeEnabled()
            ? AppConstants.systemMetricsLowPowerInterval
            : AppConstants.systemMetricsInterval
    }

    func updateMemoryPressure(_ pressure: SystemMemoryPressure) {
        memoryPressure = pressure
        refresh()
    }

    static func makeSample(
        raw: RawSystemMetrics,
        previous: RawSystemMetrics?,
        memoryPressure: SystemMemoryPressure
    ) -> SystemMetricsSample {
        let elapsed = previous.map { raw.timestamp.timeIntervalSince($0.timestamp) } ?? 0
        let cpu: Double?
        if let current = raw.cpuTicks, let prior = previous?.cpuTicks {
            let totalCurrent = current.user + current.system + current.idle + current.nice
            let totalPrior = prior.user + prior.system + prior.idle + prior.nice
            let activeCurrent = current.user + current.system + current.nice
            let activePrior = prior.user + prior.system + prior.nice
            let totalDelta = totalCurrent >= totalPrior ? totalCurrent - totalPrior : 0
            let activeDelta = activeCurrent >= activePrior ? activeCurrent - activePrior : 0
            cpu = totalDelta > 0 ? min(max(Double(activeDelta) / Double(totalDelta) * 100, 0), 100) : nil
        } else {
            cpu = nil
        }

        func rate(current: UInt64, previous: UInt64?) -> Double? {
            guard let previous, elapsed > 0, current >= previous else { return nil }
            return Double(current - previous) / elapsed
        }

        return SystemMetricsSample(
            timestamp: raw.timestamp,
            cpuUsagePercentage: cpu,
            memory: SystemMemoryMetrics(
                usedBytes: raw.usedMemoryBytes,
                totalBytes: raw.totalMemoryBytes,
                swapUsedBytes: raw.swapUsedBytes,
                pressure: memoryPressure
            ),
            network: SystemNetworkMetrics(
                receivedBytesPerSecond: rate(current: raw.receivedNetworkBytes, previous: previous?.receivedNetworkBytes),
                sentBytesPerSecond: rate(current: raw.sentNetworkBytes, previous: previous?.sentNetworkBytes)
            ),
            storage: raw.storage,
            battery: raw.battery,
            thermalState: raw.thermalState
        )
    }

    static func sortedProcesses(_ processes: [SystemProcessMetric], by sort: SystemProcessSort) -> [SystemProcessMetric] {
        Array(processes.sorted {
            switch sort {
            case .cpu:
                $0.cpuUsagePercentage == $1.cpuUsagePercentage ? $0.pid < $1.pid : $0.cpuUsagePercentage > $1.cpuUsagePercentage
            case .memory:
                $0.memoryBytes == $1.memoryBytes ? $0.pid < $1.pid : $0.memoryBytes > $1.memoryBytes
            }
        }.prefix(3))
    }

    static func trimmedSamples(
        _ samples: [SystemMetricsSample],
        at referenceDate: Date
    ) -> [SystemMetricsSample] {
        let cutoff = referenceDate.addingTimeInterval(-AppConstants.systemMetricsHistoryInterval)
        return samples.filter { $0.timestamp >= cutoff }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: samplingInterval(), repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refresh()
                let desiredInterval = self.samplingInterval()
                if abs((self.timer?.timeInterval ?? desiredInterval) - desiredInterval) > 0.1 {
                    self.scheduleTimer()
                }
            }
        }
    }

    private func refreshProcessesIfNeeded(force: Bool = false) {
        guard processTask == nil else { return }
        let now = Date()
        guard force || lastProcessRefresh.map({ now.timeIntervalSince($0) >= AppConstants.processMetricsInterval }) != false else { return }
        let collector = processCollector
        processTask = Task { [weak self] in
            let processes = await Task.detached(priority: .utility) { collector.readTopProcesses() }.value
            guard !Task.isCancelled else { return }
            self?.topProcesses = processes
            self?.lastProcessRefresh = Date()
            self?.processTask = nil
        }
    }

    private func installSystemObservers() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let events = source.data
                if events.contains(.critical) {
                    self.updateMemoryPressure(.critical)
                } else if events.contains(.warning) {
                    self.updateMemoryPressure(.warning)
                } else if events.contains(.normal) {
                    self.updateMemoryPressure(.normal)
                }
            }
        }
        source.activate()
        memoryPressureSource = source
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
}
