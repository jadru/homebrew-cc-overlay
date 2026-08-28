import Foundation
import Observation

struct DockerStorageCategory: Identifiable, Equatable, Sendable {
    let type: String
    let bytes: UInt64

    var id: String { type }

    var label: String {
        switch type {
        case "Images": "Images"
        case "Containers": "Containers"
        case "Local Volumes": "Volumes"
        case "Build Cache": "Build cache"
        default: type
        }
    }
}

struct DockerVolumeStorage: Identifiable, Equatable, Sendable {
    let name: String
    let bytes: UInt64
    let linkCount: Int

    var id: String { name }
}

struct DockerStorageSnapshot: Equatable, Sendable {
    let categories: [DockerStorageCategory]
    let volumeCount: Int
    let largestVolumes: [DockerVolumeStorage]
}

protocol DockerStorageCollecting: Sendable {
    func readStorage() -> DockerStorageSnapshot?
}

struct DockerStorageCollector: DockerStorageCollecting {
    private static let executableCandidates = [
        "/opt/homebrew/bin/docker",
        "/usr/local/bin/docker",
        "/Applications/Docker.app/Contents/Resources/bin/docker",
    ]
    private static let commandTimeout: TimeInterval = 8

    func readStorage() -> DockerStorageSnapshot? {
        guard let executablePath = Self.executableCandidates.first(where: FileManager.default.isExecutableFile),
              let summaryOutput = Self.runDocker(
                executablePath: executablePath,
                arguments: ["system", "df", "--format", "{{json .}}"]
              ),
              let volumeOutput = Self.runDocker(
                executablePath: executablePath,
                arguments: ["system", "df", "-v", "--format", "{{json .Volumes}}"]
              )
        else {
            return nil
        }

        return Self.makeSnapshot(summaryOutput: summaryOutput, volumeOutput: volumeOutput)
    }

    static func makeSnapshot(summaryOutput: String, volumeOutput: String) -> DockerStorageSnapshot? {
        let categories = parseSummaryOutput(summaryOutput)
        guard !categories.isEmpty else { return nil }

        let volumes = parseVolumeOutput(volumeOutput)
        let reportedVolumeCount = summaryOutput
            .split(whereSeparator: \.isNewline)
            .compactMap { try? JSONDecoder().decode(SummaryRow.self, from: Data($0.utf8)) }
            .first(where: { $0.type == "Local Volumes" })?
            .totalCount

        return DockerStorageSnapshot(
            categories: categories,
            volumeCount: Int(reportedVolumeCount ?? "") ?? volumes.count,
            largestVolumes: Array(volumes.sorted { lhs, rhs in
                lhs.bytes == rhs.bytes ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending : lhs.bytes > rhs.bytes
            }.prefix(3))
        )
    }

    static func parseSummaryOutput(_ output: String) -> [DockerStorageCategory] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { try? JSONDecoder().decode(SummaryRow.self, from: Data($0.utf8)) }
            .compactMap { row in
                guard let bytes = parseBytes(row.size) else { return nil }
                return DockerStorageCategory(type: row.type, bytes: bytes)
            }
    }

    static func parseVolumeOutput(_ output: String) -> [DockerVolumeStorage] {
        guard let rows = try? JSONDecoder().decode([VolumeRow].self, from: Data(output.utf8)) else { return [] }
        return rows.compactMap { row in
            guard let bytes = parseBytes(row.size) else { return nil }
            return DockerVolumeStorage(
                name: row.name,
                bytes: bytes,
                linkCount: Int(row.links) ?? 0
            )
        }
    }

    static func parseBytes(_ value: String) -> UInt64? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let unitStart = trimmed.firstIndex(where: { !$0.isNumber && $0 != "." }) else {
            return UInt64(trimmed)
        }

        let amountText = String(trimmed[..<unitStart])
        let unit = trimmed[unitStart...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard let amount = Double(amountText) else { return nil }

        let multiplier: Double
        switch unit {
        case "B": multiplier = 1
        case "KB": multiplier = 1_000
        case "MB": multiplier = 1_000_000
        case "GB": multiplier = 1_000_000_000
        case "TB": multiplier = 1_000_000_000_000
        case "KIB": multiplier = 1_024
        case "MIB": multiplier = 1_024 * 1_024
        case "GIB": multiplier = 1_024 * 1_024 * 1_024
        case "TIB": multiplier = 1_024 * 1_024 * 1_024 * 1_024
        default: return nil
        }
        return UInt64((amount * multiplier).rounded())
    }

    private static func runDocker(executablePath: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        let executableDirectory = URL(fileURLWithPath: executablePath).deletingLastPathComponent().path
        let inheritedPaths = environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        environment["PATH"] = ([executableDirectory, "/usr/bin", "/bin", "/usr/sbin", "/sbin"] + inheritedPaths)
            .reduce(into: [String]()) { paths, path in
                if !paths.contains(path) { paths.append(path) }
            }
            .joined(separator: ":")
        process.environment = environment

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        guard (try? process.run()) != nil else { return nil }

        // `readDataToEndOfFile()` drains output while Docker is running, so a
        // large volume listing cannot block on the pipe buffer. The collector
        // already runs off the main actor; this work item only enforces the
        // command timeout and does not write the command output to disk.
        let timeout = DispatchWorkItem {
            guard process.isRunning else { return }
            process.terminate()
        }
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + commandTimeout,
            execute: timeout
        )

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        timeout.cancel()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        return String(data: outputData, encoding: .utf8)
    }

    private struct SummaryRow: Decodable {
        let type: String
        let size: String
        let totalCount: String

        enum CodingKeys: String, CodingKey {
            case type = "Type"
            case size = "Size"
            case totalCount = "TotalCount"
        }
    }

    private struct VolumeRow: Decodable {
        let name: String
        let size: String
        let links: String

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case size = "Size"
            case links = "Links"
        }
    }
}

@Observable
@MainActor
final class DockerStorageService {
    private(set) var snapshot: DockerStorageSnapshot?
    private(set) var isRefreshing = false
    private(set) var lastRefresh: Date?

    private let collector: any DockerStorageCollecting
    private var refreshTask: Task<Void, Never>?

    init(collector: any DockerStorageCollecting = DockerStorageCollector()) {
        self.collector = collector
    }

    func refreshIfNeeded(maxAge: TimeInterval = 30) {
        guard !isRefreshing,
              lastRefresh.map({ Date().timeIntervalSince($0) >= maxAge }) ?? true
        else {
            return
        }
        refresh()
    }

    func refresh() {
        guard refreshTask == nil else { return }
        isRefreshing = true
        let collector = collector
        refreshTask = Task { [weak self] in
            let snapshot = await Task.detached(priority: .utility) {
                collector.readStorage()
            }.value
            guard let self, !Task.isCancelled else { return }
            self.snapshot = snapshot
            self.lastRefresh = Date()
            self.isRefreshing = false
            self.refreshTask = nil
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
    }
}
