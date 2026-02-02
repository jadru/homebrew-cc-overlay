import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class SessionMonitor {
    private(set) var activeSessions: [ActiveSession] = []
    private(set) var lastScan: Date?

    private var scanTimer: Timer?
    private var indexCache: [String: (entry: SessionIndexEntry, projectDir: String)] = [:]
    private let claudeProjectsPath: String

    var activeSessionCount: Int { activeSessions.count }
    var hasActiveSessions: Bool { !activeSessions.isEmpty }

    init(claudeProjectsPath: String = AppConstants.claudeProjectsPath, autoStart: Bool = true) {
        self.claudeProjectsPath = claudeProjectsPath
        if autoStart {
            Task { @MainActor [self] in
                startMonitoring()
            }
        }
    }

    func startMonitoring(interval: TimeInterval = AppConstants.sessionScanInterval) {
        Task { await scan() }
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.scan() }
        }
    }

    func stopMonitoring() {
        scanTimer?.invalidate()
        scanTimer = nil
    }

    func scan() async {
        let output = await runPSAsync()
        let processes = Self.parseProcessOutput(output)
        let ppidMap = Self.buildPpidMap(output)
        let appMap = Self.buildRunningAppMap()
        rebuildIndexCache()
        activeSessions = processes.map { enrichProcess($0, ppidMap: ppidMap, appMap: appMap) }
        lastScan = Date()
    }

    // MARK: - Process Detection

    struct ClaudeProcess: Sendable, Equatable {
        let pid: Int32
        let ppid: Int32
        let startTime: Date
        let sessionId: String?
        let model: String?
        let permissionMode: String?
    }

    private nonisolated func runPSAsync() async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/ps")
                process.arguments = ["-eo", "pid,ppid,lstart,command"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: "")
                    return
                }

                // Read pipe BEFORE waitUntilExit to avoid deadlock when
                // output exceeds the pipe buffer size (~64KB).
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
        }
    }

    static func parseProcessOutput(_ output: String) -> [ClaudeProcess] {
        var results: [ClaudeProcess] = []

        for line in output.components(separatedBy: "\n") {
            guard let proc = parseProcessLine(line) else { continue }
            results.append(proc)
        }

        return results
    }

    static func parseProcessLine(_ line: String) -> ClaudeProcess? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Must contain /bin/claude or end with /claude followed by a space/flags
        guard trimmed.contains("/claude ") || trimmed.hasSuffix("/claude") else { return nil }
        // Filter out grep and ps helper processes
        guard !trimmed.contains("grep") else { return nil }

        // Parse PID and PPID (first two whitespace-separated fields)
        let components = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard components.count == 3,
              let pid = Int32(components[0]),
              let ppid = Int32(components[1]) else { return nil }

        let rest = String(components[2])

        // Parse lstart: format is like "Mon Feb  2 20:54:25 2026" (always 24 chars on macOS)
        let startTime = parseLstartFromRest(rest)

        // Extract command-line flags
        let sessionId = extractFlag("--resume", from: rest)
        let model = extractFlag("--model", from: rest)
        let permissionMode = extractFlag("--permission-mode", from: rest)

        return ClaudeProcess(
            pid: pid,
            ppid: ppid,
            startTime: startTime ?? Date(),
            sessionId: sessionId,
            model: model,
            permissionMode: permissionMode
        )
    }

    /// Parse the lstart date from the rest of the ps line (after PID).
    /// macOS ps lstart format: "Mon Feb  2 20:54:25 2026" (space-padded day)
    static func parseLstartFromRest(_ rest: String) -> Date? {
        // Regex handles variable whitespace between month and day
        let pattern = /([A-Z][a-z]{2})\s+([A-Z][a-z]{2})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})/
        guard let match = rest.prefixMatch(of: pattern) else { return nil }

        let months: [String: Int] = [
            "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
            "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12,
        ]
        guard let month = months[String(match.2)] else { return nil }

        var components = DateComponents()
        components.year = Int(match.7)
        components.month = month
        components.day = Int(match.3)
        components.hour = Int(match.4)
        components.minute = Int(match.5)
        components.second = Int(match.6)

        return Calendar(identifier: .gregorian).date(from: components)
    }

    /// Extract a flag value from a command-line string.
    /// e.g., extractFlag("--resume", from: "... --resume abc-123 --model opus") returns "abc-123"
    static func extractFlag(_ flag: String, from command: String) -> String? {
        // Split keeping only non-empty parts to handle multiple spaces
        let parts = command.split(separator: " ").map(String.init)
        guard let index = parts.firstIndex(of: flag),
              index + 1 < parts.count else { return nil }
        let value = parts[index + 1]
        return value.hasPrefix("-") ? nil : value
    }

    // MARK: - Parent App Resolution

    /// Build a PID → PPID map from the full ps output.
    static func buildPpidMap(_ output: String) -> [Int32: Int32] {
        var map: [Int32: Int32] = [:]
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 2,
                  let pid = Int32(parts[0]),
                  let ppid = Int32(parts[1]) else { continue }
            map[pid] = ppid
        }
        return map
    }

    /// Build a map of PID → NSRunningApplication for all regular (GUI) apps.
    static func buildRunningAppMap() -> [Int32: NSRunningApplication] {
        var map: [Int32: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications {
            if app.activationPolicy == .regular {
                map[app.processIdentifier] = app
            }
        }
        return map
    }

    /// Walk up the PPID chain from a process to find its parent GUI application.
    static func resolveParentApp(
        pid: Int32,
        ppidMap: [Int32: Int32],
        appMap: [Int32: NSRunningApplication]
    ) -> NSRunningApplication? {
        var current = pid
        var visited: Set<Int32> = [pid]
        while let ppid = ppidMap[current] {
            if visited.contains(ppid) { break }
            visited.insert(ppid)
            if let app = appMap[ppid] { return app }
            current = ppid
        }
        return nil
    }

    // MARK: - Session Index

    private func rebuildIndexCache() {
        indexCache.removeAll()
        let fm = FileManager.default
        let projectsURL = URL(fileURLWithPath: claudeProjectsPath)

        guard let projectDirs = try? fm.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return }

        for projectDir in projectDirs {
            let indexPath = projectDir.appendingPathComponent("sessions-index.json")
            guard let data = try? Data(contentsOf: indexPath),
                  let index = try? JSONDecoder().decode(SessionIndexFile.self, from: data)
            else { continue }

            for entry in index.entries {
                indexCache[entry.sessionId] = (entry, projectDir.lastPathComponent)
            }
        }
    }

    // MARK: - Enrichment

    private func enrichProcess(
        _ proc: ClaudeProcess,
        ppidMap: [Int32: Int32],
        appMap: [Int32: NSRunningApplication]
    ) -> ActiveSession {
        var entry: SessionIndexEntry?
        var sessionId = proc.sessionId ?? "pid-\(proc.pid)"

        if let sid = proc.sessionId, let cached = indexCache[sid] {
            entry = cached.entry
        } else if proc.sessionId == nil {
            // New session without --resume: find the most recently modified index entry
            // near the process start time
            if let match = findRecentIndexEntry(near: proc.startTime) {
                entry = match
                sessionId = match.sessionId
            }
        }

        let parentApp = Self.resolveParentApp(pid: proc.pid, ppidMap: ppidMap, appMap: appMap)

        return ActiveSession(
            id: sessionId,
            pid: proc.pid,
            processStartTime: proc.startTime,
            projectPath: entry?.projectPath,
            projectName: entry?.projectPath.flatMap { URL(fileURLWithPath: $0).lastPathComponent },
            gitBranch: entry?.gitBranch,
            messageCount: entry?.messageCount,
            lastModified: entry?.modified.flatMap { parseISO8601($0) },
            model: proc.model,
            permissionMode: proc.permissionMode,
            isSidechain: entry?.isSidechain ?? false,
            parentAppBundleId: parentApp?.bundleIdentifier,
            parentAppName: parentApp?.localizedName
        )
    }

    private func findRecentIndexEntry(near processStart: Date) -> SessionIndexEntry? {
        let threshold: TimeInterval = 120 // 2 minute window
        var bestMatch: SessionIndexEntry?
        var bestDelta: TimeInterval = .greatestFiniteMagnitude

        for (_, cached) in indexCache {
            // Use created timestamp — it stays close to process start time
            // unlike modified which drifts as the session runs
            guard let createdStr = cached.entry.created,
                  let created = parseISO8601(createdStr) else { continue }

            let delta = abs(created.timeIntervalSince(processStart))
            if delta < threshold && delta < bestDelta {
                bestDelta = delta
                bestMatch = cached.entry
            }
        }

        return bestMatch
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
