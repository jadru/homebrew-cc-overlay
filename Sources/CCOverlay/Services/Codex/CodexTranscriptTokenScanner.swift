import Foundation

/// Reads the cumulative token counters that Codex writes into its local rollout
/// journals. This is a fallback for app-server builds that expose rate limits
/// but do not answer `account/usage/read`.
struct CodexTranscriptTokenScanner: Sendable {
    struct FileState: Sendable {
        let offset: UInt64
        let modificationDate: Date
        let cumulativeTokens: Int
        let trailingLine: Data
    }

    struct ScanResult: Sendable {
        let cumulativeTokens: Int
        let hasTokenData: Bool
        let fileStates: [String: FileState]
    }

    /// Only recently touched journals are relevant while the overlay is open.
    /// Keeping a per-file state means older journals remain in the in-memory
    /// total without re-reading the user's archive on every refresh.
    static func scan(
        codexHome: String,
        previousStates: [String: FileState],
        now: Date = Date()
    ) throws -> ScanResult {
        let fileManager = FileManager.default
        let cutoff = now.addingTimeInterval(-AppConstants.codexTranscriptLookback)
        var nextStates = previousStates

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
                    // Codex may touch a journal without appending a record.
                    // Rollout journals are append-only, so the byte offset is
                    // the meaningful change detector here.
                    continue
                }

                let mustRestart = previousStates[path].map { size < $0.offset } ?? true

                if mustRestart {
                    // A large pre-existing archive is only a baseline, not a
                    // reason to delay launch. New journals are picked up while
                    // small, then read incrementally after that.
                    guard size <= AppConstants.codexTranscriptInitialReadMaximumBytes else {
                        continue
                    }
                    let data = try Data(contentsOf: file)
                    let result = parseCompleteLines(in: data)
                    nextStates[path] = FileState(
                        offset: UInt64(data.count),
                        modificationDate: modificationDate,
                        cumulativeTokens: result.cumulativeTokens,
                        trailingLine: result.trailingLine
                    )
                } else if let previous = previousStates[path] {
                    let appended = try readAppendedData(from: file, offset: previous.offset)
                    let result = parseCompleteLines(in: previous.trailingLine + appended)
                    nextStates[path] = FileState(
                        offset: size,
                        modificationDate: modificationDate,
                        cumulativeTokens: max(previous.cumulativeTokens, result.cumulativeTokens),
                        trailingLine: result.trailingLine
                    )
                }
            }
        }

        let statesWithTokenData = nextStates.values.filter { $0.cumulativeTokens > 0 }
        return ScanResult(
            cumulativeTokens: statesWithTokenData.reduce(0) { $0 + $1.cumulativeTokens },
            hasTokenData: !statesWithTokenData.isEmpty,
            fileStates: nextStates
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

    private static func parseCompleteLines(in data: Data) -> (cumulativeTokens: Int, trailingLine: Data) {
        var latestTotal = 0
        var lineStart = data.startIndex

        while let newline = data[lineStart...].firstIndex(of: 0x0A) {
            let line = Data(data[lineStart..<newline])
            latestTotal = max(latestTotal, cumulativeTokens(in: line) ?? 0)
            lineStart = data.index(after: newline)
        }

        return (latestTotal, Data(data[lineStart...]))
    }

    private static func cumulativeTokens(in line: Data) -> Int? {
        guard let root = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let payload = root["payload"] as? [String: Any],
              payload["type"] as? String == "token_count",
              let info = payload["info"] as? [String: Any],
              let usage = info["total_token_usage"] as? [String: Any]
        else {
            return nil
        }

        switch usage["total_tokens"] {
        case let number as NSNumber:
            return max(number.intValue, 0)
        case let text as String:
            return max(Int(text) ?? 0, 0)
        default:
            return nil
        }
    }
}
