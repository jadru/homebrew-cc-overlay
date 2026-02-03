import Foundation
import XCTest

@testable import CCOverlay

final class JSONLParserTests: XCTestCase {

    private func createTempFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".jsonl")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func testParseAssistantMessageWithUsageData() throws {
        let jsonl = """
            {"type":"assistant","sessionId":"test-session","timestamp":"2026-01-30T01:16:00.351Z","message":{"model":"claude-opus-4-5-20251101","role":"assistant","usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":200,"cache_read_input_tokens":300,"service_tier":"standard"}}}
            """

        let file = try createTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: file) }

        let entries = try JSONLParser.parseSessionFile(at: file)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].sessionId, "test-session")
        XCTAssertEqual(entries[0].model, "claude-opus-4-5-20251101")
        XCTAssertEqual(entries[0].inputTokens, 100)
        XCTAssertEqual(entries[0].outputTokens, 50)
        XCTAssertEqual(entries[0].cacheCreationTokens, 200)
        XCTAssertEqual(entries[0].cacheReadTokens, 300)
    }

    func testSkipNonAssistantEntries() throws {
        let jsonl = """
            {"type":"user","sessionId":"test","timestamp":"2026-01-30T01:00:00.000Z","message":{"role":"user"}}
            {"type":"queue-operation","operation":"dequeue","timestamp":"2026-01-30T01:00:00.000Z"}
            {"type":"assistant","sessionId":"test","timestamp":"2026-01-30T01:01:00.000Z","message":{"model":"claude-opus-4-5-20251101","role":"assistant","usage":{"input_tokens":10,"output_tokens":5}}}
            """

        let file = try createTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: file) }

        let entries = try JSONLParser.parseSessionFile(at: file)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].inputTokens, 10)
    }

    func testHandleMissingOptionalFields() throws {
        let jsonl = """
            {"type":"assistant","timestamp":"2026-01-30T01:00:00.000Z","message":{"role":"assistant","usage":{"input_tokens":10,"output_tokens":5}}}
            """

        let file = try createTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: file) }

        let entries = try JSONLParser.parseSessionFile(at: file)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].cacheCreationTokens, 0)
        XCTAssertEqual(entries[0].cacheReadTokens, 0)
        XCTAssertEqual(entries[0].model, "unknown")
    }

    func testHandleEmptyFile() throws {
        let file = try createTempFile(content: "")
        defer { try? FileManager.default.removeItem(at: file) }

        let entries = try JSONLParser.parseSessionFile(at: file)
        XCTAssertTrue(entries.isEmpty)
    }

    func testHandleMalformedLines() throws {
        let jsonl = """
            not valid json
            {"type":"assistant","timestamp":"2026-01-30T01:00:00.000Z","message":{"role":"assistant","usage":{"input_tokens":10,"output_tokens":5}}}
            also not valid
            """

        let file = try createTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: file) }

        let entries = try JSONLParser.parseSessionFile(at: file)
        XCTAssertEqual(entries.count, 1)
    }

    func testMultipleAssistantMessages() throws {
        let jsonl = """
            {"type":"assistant","sessionId":"s1","timestamp":"2026-01-30T01:00:00.000Z","message":{"model":"claude-opus-4-5-20251101","role":"assistant","usage":{"input_tokens":100,"output_tokens":50}}}
            {"type":"assistant","sessionId":"s1","timestamp":"2026-01-30T01:05:00.000Z","message":{"model":"claude-opus-4-5-20251101","role":"assistant","usage":{"input_tokens":200,"output_tokens":100,"cache_creation_input_tokens":50}}}
            {"type":"assistant","sessionId":"s1","timestamp":"2026-01-30T01:10:00.000Z","message":{"model":"claude-opus-4-5-20251101","role":"assistant","usage":{"input_tokens":300,"output_tokens":150,"cache_read_input_tokens":75}}}
            """

        let file = try createTempFile(content: jsonl)
        defer { try? FileManager.default.removeItem(at: file) }

        let entries = try JSONLParser.parseSessionFile(at: file)

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].inputTokens, 100)
        XCTAssertEqual(entries[1].inputTokens, 200)
        XCTAssertEqual(entries[1].cacheCreationTokens, 50)
        XCTAssertEqual(entries[2].inputTokens, 300)
        XCTAssertEqual(entries[2].cacheReadTokens, 75)
    }
}
