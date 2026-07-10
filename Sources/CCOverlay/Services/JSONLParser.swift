import Foundation

enum ParserError: Error {
    case invalidEncoding
    case fileNotFound
}

struct JSONLParser: Sendable {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    /// Parse a single JSONL file and extract all usage entries from assistant messages.
    static func parseSessionFile(at url: URL, projectName: String? = nil) throws -> [ParsedUsageEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ParserError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        guard String(data: data, encoding: .utf8) != nil else {
            throw ParserError.invalidEncoding
        }

        let result = parseCompleteLines(
            in: data,
            sessionId: url.deletingPathExtension().lastPathComponent,
            projectName: projectName
        )
        var entries = result.entries

        // Historical JSONL files can end without a trailing newline. Incremental
        // scanning keeps this buffer, while a one-shot parse should include it.
        if !result.trailingLine.isEmpty,
           let trailingEntry = parseEntry(
               from: result.trailingLine,
               sessionId: url.deletingPathExtension().lastPathComponent,
               projectName: projectName
           )
        {
            entries.append(trailingEntry)
        }

        return entries
    }

    struct IncrementalResult: Sendable {
        let entries: [ParsedUsageEntry]
        let trailingLine: Data
    }

    /// Parses complete newline-delimited records and preserves an unfinished line
    /// for the next append operation.
    static func parseCompleteLines(
        in data: Data,
        sessionId: String,
        projectName: String?
    ) -> IncrementalResult {
        var entries: [ParsedUsageEntry] = []
        var lineStart = data.startIndex

        while let newline = data[lineStart...].firstIndex(of: 0x0A) {
            let line = data[lineStart..<newline]
            if let entry = parseEntry(from: Data(line), sessionId: sessionId, projectName: projectName) {
                entries.append(entry)
            }
            lineStart = data.index(after: newline)
        }

        return IncrementalResult(
            entries: entries,
            trailingLine: Data(data[lineStart...])
        )
    }

    private static func parseEntry(
        from lineData: Data,
        sessionId: String,
        projectName: String?
    ) -> ParsedUsageEntry? {
        guard !lineData.isEmpty,
              let entry = try? decoder.decode(JournalEntry.self, from: lineData),
              entry.type == "assistant",
              let usage = entry.message?.usage,
              let timestampStr = entry.timestamp,
              let timestamp = DateParsing.parseISO8601(timestampStr)
        else {
            return nil
        }

        return ParsedUsageEntry(
            sessionId: entry.sessionId ?? sessionId,
            model: entry.message?.model ?? "unknown",
            inputTokens: usage.input_tokens ?? 0,
            outputTokens: usage.output_tokens ?? 0,
            cacheCreationTokens: usage.cache_creation_input_tokens ?? 0,
            cacheReadTokens: usage.cache_read_input_tokens ?? 0,
            timestamp: timestamp,
            projectName: projectName
        )
    }

}
