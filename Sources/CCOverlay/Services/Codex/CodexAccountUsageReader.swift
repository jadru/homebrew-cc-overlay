import Foundation

enum CodexAccountUsageReader {
    enum ReaderError: LocalizedError {
        case unavailable
        case profileDirectoryMissing
        case timedOut
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Codex app-server is unavailable."
            case .profileDirectoryMissing: return "CODEX_HOME does not exist. Sign in to this profile first."
            case .timedOut: return "Codex account usage did not respond in time."
            case .invalidResponse: return "Codex returned an invalid account usage response."
            case .server(let message): return message
            }
        }
    }

    static func fetch(
        profile: CodexAccountProfile,
        binaryPath: String,
        timeout: TimeInterval = 8
    ) async throws -> CodexAccountUsageSnapshot {
        try await Task.detached(priority: .utility) {
            try query(profile: profile, binaryPath: binaryPath, timeout: timeout)
        }.value
    }

    static func parse(
        profileID: UUID,
        rateLimitsResponse: Data,
        tokenUsageResponse: Data,
        fetchedAt: Date = Date()
    ) throws -> CodexAccountUsageSnapshot {
        let rateRoot = try responseResult(from: rateLimitsResponse)
        let usageRoot = try responseResult(from: tokenUsageResponse)

        let rateLimits = rateRoot["rateLimits"] as? [String: Any]
            ?? (rateRoot["rateLimitsByLimitId"] as? [String: [String: Any]])?["codex"]
        guard let rateLimits else { throw ReaderError.invalidResponse }

        let primaryWindow = parseWindow(rateLimits["primary"])
        let secondaryWindow = parseWindow(rateLimits["secondary"])
        guard primaryWindow != nil || secondaryWindow != nil else {
            throw ReaderError.invalidResponse
        }

        let summary = usageRoot["summary"] as? [String: Any] ?? [:]
        let dailyBuckets: [CodexDailyTokenUsage] = (
            usageRoot["dailyUsageBuckets"] as? [[String: Any]] ?? []
        ).compactMap { item -> CodexDailyTokenUsage? in
            guard let date = item["startDate"] as? String,
                  let tokens = integerValue(item["tokens"])
            else { return nil }
            return CodexDailyTokenUsage(startDate: date, tokens: max(tokens, 0))
        }

        return CodexAccountUsageSnapshot(
            profileID: profileID,
            planType: rateLimits["planType"] as? String,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            tokenActivity: CodexTokenActivity(
                lifetimeTokens: integerValue(summary["lifetimeTokens"]),
                peakDailyTokens: integerValue(summary["peakDailyTokens"]),
                longestRunningTurnSeconds: integerValue(summary["longestRunningTurnSec"]),
                currentStreakDays: integerValue(summary["currentStreakDays"]),
                longestStreakDays: integerValue(summary["longestStreakDays"]),
                dailyBuckets: dailyBuckets.sorted { $0.startDate < $1.startDate }
            ),
            fetchedAt: fetchedAt
        )
    }

    nonisolated private static func query(
        profile: CodexAccountProfile,
        binaryPath: String,
        timeout: TimeInterval
    ) throws -> CodexAccountUsageSnapshot {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            throw ReaderError.unavailable
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: profile.codexHome, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw ReaderError.profileDirectoryMissing
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let collector = CodexAccountResponseCollector(responseIDs: [1, 2, 3])

        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["app-server", "--listen", "stdio://"]
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = profile.codexHome
        process.environment = environment
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            collector.consume(handle.availableData)
        }

        defer {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            try? inputPipe.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }

        do {
            try process.run()
        } catch {
            throw ReaderError.unavailable
        }

        let messages = appServerRequestMessages()

        func send(_ message: [String: Any]) throws {
            let encoded = try JSONSerialization.data(withJSONObject: message)
            try inputPipe.fileHandleForWriting.write(contentsOf: encoded + Data([0x0A]))
        }

        // Codex app-server requires its initialize response to be received
        // before the client sends `initialized` or any account request.
        try send(messages[0])
        guard collector.wait(for: [1], timeout: timeout) else {
            throw ReaderError.timedOut
        }
        try send(messages[1])
        try send(messages[2])
        try send(messages[3])

        guard collector.wait(for: [2, 3], timeout: timeout),
              let rateLimits = collector.response(for: 2),
              let tokenUsage = collector.response(for: 3)
        else {
            throw ReaderError.timedOut
        }

        return try parse(
            profileID: profile.id,
            rateLimitsResponse: rateLimits,
            tokenUsageResponse: tokenUsage
        )
    }

    /// The Codex app-server schema represents these requests without a
    /// `params` object.
    static func appServerRequestMessages() -> [[String: Any]] {
        [
            [
                "method": "initialize",
                "id": 1,
                "params": [
                    "clientInfo": [
                        "name": "cc_overlay",
                        "title": "CC-Overlay",
                        "version": AppConstants.version,
                    ],
                ],
            ],
            ["method": "initialized"],
            ["method": "account/rateLimits/read", "id": 2],
            ["method": "account/usage/read", "id": 3],
        ]
    }

    nonisolated private static func responseResult(from data: Data) throws -> [String: Any] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ReaderError.invalidResponse
        }
        if let error = root["error"] as? [String: Any] {
            throw ReaderError.server(error["message"] as? String ?? "Codex account request failed.")
        }
        guard let result = root["result"] as? [String: Any] else {
            throw ReaderError.invalidResponse
        }
        return result
    }

    nonisolated private static func parseWindow(_ value: Any?) -> CodexAccountRateWindow? {
        guard let dictionary = value as? [String: Any],
              let usedPercent = doubleValue(dictionary["usedPercent"]),
              (0...100).contains(usedPercent),
              let duration = integerValue(dictionary["windowDurationMins"]),
              duration > 0
        else { return nil }

        let resetTimestamp = doubleValue(dictionary["resetsAt"])
        return CodexAccountRateWindow(
            usedPercent: usedPercent,
            windowDurationMinutes: duration,
            resetsAt: resetTimestamp.map { Date(timeIntervalSince1970: $0) }
        )
    }

    nonisolated private static func integerValue(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber: return number.intValue
        case let text as String: return Int(text)
        default: return nil
        }
    }

    nonisolated private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: return number.doubleValue
        case let text as String: return Double(text)
        default: return nil
        }
    }
}

private final class CodexAccountResponseCollector: @unchecked Sendable {
    private let responseIDs: Set<Int>
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var buffer = Data()
    private var responses: [Int: Data] = [:]

    init(responseIDs: Set<Int>) {
        self.responseIDs = responseIDs
    }

    func response(for id: Int) -> Data? {
        lock.withLock { responses[id] }
    }

    func consume(_ data: Data) {
        guard !data.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)

        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let id = (object["id"] as? NSNumber)?.intValue,
                  responseIDs.contains(id)
            else { continue }
            responses[id] = line
        }

        semaphore.signal()
    }

    func wait(for responseIDs: Set<Int>, timeout: TimeInterval) -> Bool {
        let deadline = DispatchTime.now() + timeout
        while !lock.withLock({ responseIDs.isSubset(of: Set(responses.keys)) }) {
            guard semaphore.wait(timeout: deadline) == .success else { return false }
        }
        return true
    }
}
