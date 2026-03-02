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
        guard let content = String(data: data, encoding: .utf8) else {
            throw ParserError.invalidEncoding
        }

        var entries: [ParsedUsageEntry] = []
        let sessionId = url.deletingPathExtension().lastPathComponent

        for line in content.components(separatedBy: .newlines) {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8)
            else { continue }

            guard let entry = try? decoder.decode(JournalEntry.self, from: lineData),
                  entry.type == "assistant",
                  let usage = entry.message?.usage,
                  let timestampStr = entry.timestamp,
                  let timestamp = DateParsing.parseISO8601(timestampStr)
            else { continue }

            entries.append(
                ParsedUsageEntry(
                    sessionId: entry.sessionId ?? sessionId,
                    model: entry.message?.model ?? "unknown",
                    inputTokens: usage.input_tokens ?? 0,
                    outputTokens: usage.output_tokens ?? 0,
                    cacheCreationTokens: usage.cache_creation_input_tokens ?? 0,
                    cacheReadTokens: usage.cache_read_input_tokens ?? 0,
                    timestamp: timestamp,
                    projectName: projectName
                ))
        }

        return entries
    }

}
