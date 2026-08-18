import XCTest
@testable import CCOverlay

final class CodexTranscriptTokenScannerTests: XCTestCase {
    func testScannerReadsNewTokenTotalsIncrementally() throws {
        let codexHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-overlay-codex-token-scanner-\(UUID().uuidString)", isDirectory: true)
        let archive = codexHome.appendingPathComponent("archived_sessions", isDirectory: true)
        let transcript = archive.appendingPathComponent("rollout.jsonl")
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: codexHome) }

        try Data(tokenCountLine(total: 100).utf8).write(to: transcript)
        let initial = try CodexTranscriptTokenScanner.scan(codexHome: codexHome.path, previousStates: [:])
        XCTAssertTrue(initial.hasTokenData)
        XCTAssertEqual(initial.cumulativeTokens, 100)

        let handle = try FileHandle(forWritingTo: transcript)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(tokenCountLine(total: 175).utf8))
        try handle.close()

        let appended = try CodexTranscriptTokenScanner.scan(
            codexHome: codexHome.path,
            previousStates: initial.fileStates
        )
        XCTAssertEqual(appended.cumulativeTokens, 175)
    }

    private func tokenCountLine(total: Int) -> String {
        #"{"payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":\#(total)}}}}"# + "\n"
    }
}
