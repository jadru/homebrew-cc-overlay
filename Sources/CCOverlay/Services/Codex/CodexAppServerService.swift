import Foundation

/// Reads earned Full Reset details from the official Codex app-server protocol.
///
/// The lightweight usage endpoint only exposes counts on some accounts. Newer Codex
/// builds expose the authoritative credit rows, including nullable expiration dates,
/// through `account/rateLimits/read`. Failures are intentionally non-fatal because the
/// existing OAuth usage snapshot remains usable without the enrichment.
actor CodexAppServerService {
    private struct Cache: Sendable {
        let binaryPath: String
        let expectedCount: Int
        let snapshot: CodexOAuthService.RateLimitResetCredits
        let fetchedAt: Date
    }

    enum ServiceError: LocalizedError {
        case unavailable
        case timedOut
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Codex app-server is unavailable"
            case .timedOut: return "Codex app-server did not respond in time"
            case .invalidResponse: return "Codex app-server returned an invalid response"
            case .server(let message): return message
            }
        }
    }

    private var cache: Cache?
    private var lastFailureAt: Date?

    func fetchResetCredits(
        binaryPath: String,
        expectedCount: Int,
        now: Date = Date()
    ) async throws -> CodexOAuthService.RateLimitResetCredits {
        if let cache,
           cache.binaryPath == binaryPath,
           cache.expectedCount == expectedCount,
           now.timeIntervalSince(cache.fetchedAt) < 60 * 60 {
            return cache.snapshot
        }

        if let lastFailureAt, now.timeIntervalSince(lastFailureAt) < 60 * 60 {
            throw ServiceError.unavailable
        }

        do {
            let snapshot = try await Task.detached(priority: .utility) {
                try Self.queryResetCredits(binaryPath: binaryPath, timeout: 5)
            }.value
            cache = Cache(
                binaryPath: binaryPath,
                expectedCount: expectedCount,
                snapshot: snapshot,
                fetchedAt: now
            )
            lastFailureAt = nil
            return snapshot
        } catch {
            lastFailureAt = now
            throw error
        }
    }

    nonisolated static func parseRateLimitResetResponse(
        _ data: Data
    ) throws -> CodexOAuthService.RateLimitResetCredits {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.invalidResponse
        }
        if let error = root["error"] as? [String: Any] {
            throw ServiceError.server(error["message"] as? String ?? "Codex app-server request failed")
        }
        guard let result = root["result"] as? [String: Any],
              let resetBlock = result["rateLimitResetCredits"] as? [String: Any]
        else {
            throw ServiceError.invalidResponse
        }

        let availableCount = integerValue(resetBlock["availableCount"]) ?? 0
        let credits = (resetBlock["credits"] as? [[String: Any]] ?? []).map { item in
            CodexOAuthService.ResetCredit(
                status: item["status"] as? String ?? "available",
                grantedAt: unixDate(item["grantedAt"]),
                expiresAt: unixDate(item["expiresAt"])
            )
        }
        return CodexOAuthService.RateLimitResetCredits(
            availableCount: availableCount,
            applicableAvailableCount: 0,
            credits: credits
        )
    }

    nonisolated private static func queryResetCredits(
        binaryPath: String,
        timeout: TimeInterval
    ) throws -> CodexOAuthService.RateLimitResetCredits {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            throw ServiceError.unavailable
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let collector = CodexAppServerResponseCollector(responseID: 2)

        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["app-server", "--listen", "stdio://"]
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
            throw ServiceError.unavailable
        }

        let messages: [[String: Any]] = [
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
            ["method": "initialized", "params": [:]],
            ["method": "account/rateLimits/read", "id": 2, "params": [:]],
        ]

        for message in messages {
            let encoded = try JSONSerialization.data(withJSONObject: message)
            try inputPipe.fileHandleForWriting.write(contentsOf: encoded + Data([0x0A]))
        }

        guard collector.wait(timeout: timeout), let response = collector.response else {
            throw ServiceError.timedOut
        }
        return try parseRateLimitResetResponse(response)
    }

    nonisolated private static func integerValue(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber: return number.intValue
        case let text as String: return Int(text)
        default: return nil
        }
    }

    nonisolated private static func unixDate(_ value: Any?) -> Date? {
        let timestamp: TimeInterval?
        switch value {
        case let number as NSNumber: timestamp = number.doubleValue
        case let text as String: timestamp = TimeInterval(text)
        default: timestamp = nil
        }
        guard let timestamp, timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}

private final class CodexAppServerResponseCollector: @unchecked Sendable {
    private let responseID: Int
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var buffer = Data()
    private var storedResponse: Data?

    init(responseID: Int) {
        self.responseID = responseID
    }

    var response: Data? {
        lock.withLock { storedResponse }
    }

    func consume(_ data: Data) {
        guard !data.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }
        guard storedResponse == nil else { return }

        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  (object["id"] as? NSNumber)?.intValue == responseID
            else {
                continue
            }
            storedResponse = line
            semaphore.signal()
            return
        }
    }

    func wait(timeout: TimeInterval) -> Bool {
        semaphore.wait(timeout: .now() + timeout) == .success
    }
}
