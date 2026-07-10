import Foundation
import XCTest
@testable import CCOverlay

final class ClaudeSessionScannerTests: XCTestCase {
    func testAppendedTranscriptReadsOnlyNewRecords() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-overlay-scanner-\(UUID().uuidString)", isDirectory: true)
        let project = root.appendingPathComponent("project", isDirectory: true)
        let transcript = project.appendingPathComponent("session.jsonl")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data(assistantLine(inputTokens: 10).utf8).write(to: transcript)

        let initial = try ClaudeSessionScanner.scan(
            projectsPath: root.path,
            previousStates: [:]
        )
        XCTAssertEqual(initial.entries.count, 1)
        XCTAssertEqual(initial.entries.first?.inputTokens, 10)

        let handle = try FileHandle(forWritingTo: transcript)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(assistantLine(inputTokens: 20).utf8))
        try handle.close()

        let appended = try ClaudeSessionScanner.scan(
            projectsPath: root.path,
            previousStates: initial.fileStates
        )
        XCTAssertEqual(appended.entries.count, 2)
        XCTAssertEqual(appended.entries.map(\.inputTokens), [10, 20])

        let unchanged = try ClaudeSessionScanner.scan(
            projectsPath: root.path,
            previousStates: appended.fileStates
        )
        XCTAssertEqual(unchanged.entries.map(\.inputTokens), [10, 20])
    }

    private func assistantLine(inputTokens: Int) -> String {
        """
        {"type":"assistant","sessionId":"session","timestamp":"2026-07-10T00:00:00Z","message":{"model":"claude-sonnet","usage":{"input_tokens":\(inputTokens),"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}

        """
    }
}
