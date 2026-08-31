import Foundation

/// Safely derives display-only project activity from local Codex rollout
/// journals. Paths and transcript text remain in process memory and are never
/// exported, persisted, or included in diagnostics.
struct CodexProjectUsageScanner: Sendable {
    struct FileState: Sendable {
        let offset: UInt64
        let modificationDate: Date
        let trailingLine: Data
        let sessionId: String
        let projectName: String?
        let model: String?
        let cumulativeUsage: TokenUsage
        let entries: [ProjectUsageEntry]
        let hasUnsupportedTokenSchema: Bool
    }

    struct ScanResult: Sendable {
        let fileStates: [String: FileState]
        let hasSkippedFiles: Bool

        var hasSchemaIssue: Bool {
            fileStates.values.contains { $0.hasUnsupportedTokenSchema }
        }

        var entries: [ProjectUsageEntry] {
            fileStates.values.flatMap(\.entries)
        }
    }

    static func scan(
        codexHome: String,
        previousStates: [String: FileState],
        now: Date = Date()
    ) throws -> ScanResult {
        let fileManager = FileManager.default
        let cutoff = now.addingTimeInterval(-24 * 60 * 60)
        var nextStates = previousStates
        var hasSkippedFiles = false

        for root in journalRoots(codexHome: codexHome) {
            guard fileManager.fileExists(atPath: root.path),
                  let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: [
                        .contentModificationDateKey,
                        .fileSizeKey,
                        .isRegularFileKey,
                    ],
                    options: [.skipsHiddenFiles]
                  )
            else {
                continue
            }

            for case let file as URL in enumerator {
                guard file.pathExtension == "jsonl" else { continue }
                let values = try file.resourceValues(forKeys: [
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isRegularFileKey,
                ])
                guard values.isRegularFile == true,
                      let modificationDate = values.contentModificationDate,
                      modificationDate >= cutoff,
                      let fileSize = values.fileSize
                else {
                    continue
                }

                let path = file.path
                let size = UInt64(fileSize)
                if let previous = previousStates[path], previous.offset == size {
                    continue
                }

                let restart = previousStates[path].map { size < $0.offset } ?? true
                if restart {
                    guard size <= AppConstants.codexTranscriptInitialReadMaximumBytes else {
                        hasSkippedFiles = true
                        continue
                    }
                    let data = try Data(contentsOf: file)
                    nextStates[path] = parse(
                        data: data,
                        file: file,
                        modificationDate: modificationDate,
                        prior: nil,
                        cutoff: cutoff,
                        offset: size
                    )
                } else if let previous = previousStates[path] {
                    let appended = try readAppendedData(from: file, offset: previous.offset)
                    nextStates[path] = parse(
                        data: previous.trailingLine + appended,
                        file: file,
                        modificationDate: modificationDate,
                        prior: previous,
                        cutoff: cutoff,
                        offset: size
                    )
                }
            }
        }

        return ScanResult(fileStates: nextStates, hasSkippedFiles: hasSkippedFiles)
    }

    private static func parse(
        data: Data,
        file: URL,
        modificationDate: Date,
        prior: FileState?,
        cutoff: Date,
        offset: UInt64
    ) -> FileState {
        var trailingStart = data.startIndex
        var sessionId = prior?.sessionId ?? file.deletingPathExtension().lastPathComponent
        var projectName = prior?.projectName
        var model = prior?.model
        var cumulativeUsage = prior?.cumulativeUsage ?? .zero
        var entries = prior?.entries ?? []
        var hasUnsupportedTokenSchema = prior?.hasUnsupportedTokenSchema ?? false

        while let newline = data[trailingStart...].firstIndex(of: 0x0A) {
            let line = Data(data[trailingStart..<newline])
            if let event = parseEvent(line) {
                hasUnsupportedTokenSchema = hasUnsupportedTokenSchema || event.hasUnsupportedTokenSchema
                if let eventSessionId = event.sessionId, !eventSessionId.isEmpty {
                    sessionId = eventSessionId
                }
                if let cwd = event.cwd, !cwd.isEmpty {
                    projectName = URL(fileURLWithPath: cwd).lastPathComponent
                }
                if let eventModel = event.model, !eventModel.isEmpty {
                    model = eventModel
                }
                if let currentUsage = event.cumulativeUsage {
                    let delta = positiveDelta(current: currentUsage, previous: cumulativeUsage)
                    cumulativeUsage = currentUsage
                    if delta.totalTokens > 0,
                       let timestamp = event.timestamp,
                       timestamp >= cutoff,
                       let projectName
                    {
                        entries.append(ProjectUsageEntry(
                            provider: .codex,
                            source: .codexLocalTokens,
                            sessionId: sessionId,
                            projectName: projectName,
                            model: model,
                            timestamp: timestamp,
                            tokenUsage: delta,
                            claudeEstimatedCost: nil
                        ))
                    }
                }
            }
            trailingStart = data.index(after: newline)
        }

        return FileState(
            offset: offset,
            modificationDate: modificationDate,
            trailingLine: Data(data[trailingStart...]),
            sessionId: sessionId,
            projectName: projectName,
            model: model,
            cumulativeUsage: cumulativeUsage,
            entries: entries.filter { $0.timestamp >= cutoff },
            hasUnsupportedTokenSchema: hasUnsupportedTokenSchema
        )
    }

    private static func parseEvent(_ line: Data) -> ParsedEvent? {
        guard let root = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let payload = root["payload"] as? [String: Any]
        else {
            return nil
        }

        let metadata = payload["meta"] as? [String: Any]
        let context = payload["context"] as? [String: Any]
        let cwd = string(payload["cwd"]) ?? string(metadata?["cwd"]) ?? string(context?["cwd"])
        let model = string(payload["model"]) ?? string(context?["model"])
        let sessionId = string(root["session_id"]) ?? string(root["sessionId"])
        let timestamp = date(from: string(root["timestamp"]))

        let isTokenCount = payload["type"] as? String == "token_count"
        var cumulativeUsage: TokenUsage?
        var hasUnsupportedTokenSchema = false
        if isTokenCount {
            if let info = payload["info"] as? [String: Any],
               let usage = info["total_token_usage"] as? [String: Any]
            {
                cumulativeUsage = TokenUsage(
                    inputTokens: number(usage["input_tokens"]),
                    outputTokens: number(usage["output_tokens"]) + number(usage["reasoning_output_tokens"]),
                    cacheCreationInputTokens: number(usage["cache_creation_input_tokens"]),
                    cacheReadInputTokens: number(usage["cached_input_tokens"]) + number(usage["cache_read_input_tokens"])
                )
            } else {
                hasUnsupportedTokenSchema = true
            }
        }

        return ParsedEvent(
            sessionId: sessionId,
            cwd: cwd,
            model: model,
            timestamp: timestamp,
            cumulativeUsage: cumulativeUsage,
            hasUnsupportedTokenSchema: hasUnsupportedTokenSchema
        )
    }

    private static func positiveDelta(current: TokenUsage, previous: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: max(current.inputTokens - previous.inputTokens, 0),
            outputTokens: max(current.outputTokens - previous.outputTokens, 0),
            cacheCreationInputTokens: max(current.cacheCreationInputTokens - previous.cacheCreationInputTokens, 0),
            cacheReadInputTokens: max(current.cacheReadInputTokens - previous.cacheReadInputTokens, 0)
        )
    }

    private static func journalRoots(codexHome: String) -> [URL] {
        let home = URL(fileURLWithPath: codexHome, isDirectory: true)
        return [
            home.appendingPathComponent("archived_sessions", isDirectory: true),
            home.appendingPathComponent("sessions", isDirectory: true),
        ]
    }

    private static func readAppendedData(from file: URL, offset: UInt64) throws -> Data {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        try handle.seek(toOffset: offset)
        return try handle.readToEnd() ?? Data()
    }

    private static func number(_ value: Any?) -> Int {
        switch value {
        case let number as NSNumber: max(number.intValue, 0)
        case let text as String: max(Int(text) ?? 0, 0)
        default: 0
        }
    }

    private static func string(_ value: Any?) -> String? {
        value as? String
    }

    private static func date(from value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private struct ParsedEvent {
        let sessionId: String?
        let cwd: String?
        let model: String?
        let timestamp: Date?
        let cumulativeUsage: TokenUsage?
        let hasUnsupportedTokenSchema: Bool
    }
}
