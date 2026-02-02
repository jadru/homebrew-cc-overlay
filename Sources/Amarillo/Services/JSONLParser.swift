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

    private static nonisolated(unsafe) let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Parse a single JSONL file and extract all usage entries from assistant messages.
    static func parseSessionFile(at url: URL) throws -> [ParsedUsageEntry] {
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
                  let timestamp = parseTimestamp(timestampStr)
            else { continue }

            entries.append(
                ParsedUsageEntry(
                    sessionId: entry.sessionId ?? sessionId,
                    model: entry.message?.model ?? "unknown",
                    inputTokens: usage.input_tokens ?? 0,
                    outputTokens: usage.output_tokens ?? 0,
                    cacheCreationTokens: usage.cache_creation_input_tokens ?? 0,
                    cacheReadTokens: usage.cache_read_input_tokens ?? 0,
                    timestamp: timestamp
                ))
        }

        return entries
    }

    private static func parseTimestamp(_ string: String) -> Date? {
        if let date = isoFormatter.date(from: string) {
            return date
        }
        // Fallback: try without fractional seconds
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: string)
    }
}
