import XCTest
@testable import CCOverlay

final class CodexProjectUsageScannerTests: XCTestCase {
    func testScannerMapsCwdAndCountsOnlyPositiveCumulativeChanges() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.home) }

        let now = Date()
        try write([
            sessionMeta(cwd: "/Users/example/work/overlay", session: "one", at: now),
            tokenCount(input: 100, output: 10, session: "one", at: now),
            tokenCount(input: 100, output: 10, session: "one", at: now),
            tokenCount(input: 80, output: 10, session: "one", at: now),
            tokenCount(input: 120, output: 20, session: "one", at: now),
        ], to: fixture.transcript)

        let result = try CodexProjectUsageScanner.scan(codexHome: fixture.home.path, previousStates: [:], now: now)
        let project = try XCTUnwrap(result.entries.first)

        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(project.projectName, "overlay")
        XCTAssertEqual(project.provider, .codex)
        XCTAssertEqual(project.source, .codexLocalTokens)
        XCTAssertNil(project.claudeEstimatedCost)
        XCTAssertEqual(result.entries.reduce(0) { $0 + $1.tokenUsage.inputTokens }, 140)
        XCTAssertEqual(result.entries.reduce(0) { $0 + $1.tokenUsage.outputTokens }, 20)
    }

    func testScannerSkipsCorruptAndPathlessLinesWithoutFailing() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.home) }

        let now = Date()
        try write([
            "not-json\n",
            tokenCount(input: 100, output: 0, session: "one", at: now),
        ], to: fixture.transcript)

        let result = try CodexProjectUsageScanner.scan(codexHome: fixture.home.path, previousStates: [:], now: now)

        XCTAssertTrue(result.entries.isEmpty)
    }

    func testScannerReportsUnsupportedTokenSchemaWithoutBlockingOtherInsights() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.home) }

        let now = Date()
        try write([
            sessionMeta(cwd: "/Users/example/work/overlay", session: "one", at: now),
            "{\"timestamp\":\"\(timestamp(now))\",\"payload\":{\"type\":\"token_count\",\"info\":{}}}\n",
        ], to: fixture.transcript)

        let result = try CodexProjectUsageScanner.scan(codexHome: fixture.home.path, previousStates: [:], now: now)

        XCTAssertTrue(result.hasSchemaIssue)
        XCTAssertTrue(result.entries.isEmpty)
    }

    func testScannerSkipsFilesPastTheSafeInitialReadLimit() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.home) }

        try Data().write(to: fixture.transcript)
        let handle = try FileHandle(forWritingTo: fixture.transcript)
        try handle.truncate(atOffset: AppConstants.codexTranscriptInitialReadMaximumBytes + 1)
        try handle.close()

        let result = try CodexProjectUsageScanner.scan(codexHome: fixture.home.path, previousStates: [:])

        XCTAssertTrue(result.hasSkippedFiles)
        XCTAssertTrue(result.entries.isEmpty)
    }

    func testScannerReadsAppendedDataWithoutDoubleCountingPreviousEvents() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.home) }

        let now = Date()
        try write([
            sessionMeta(cwd: "/Users/example/work/overlay", session: "one", at: now),
            tokenCount(input: 100, output: 0, session: "one", at: now),
        ], to: fixture.transcript)
        let initial = try CodexProjectUsageScanner.scan(codexHome: fixture.home.path, previousStates: [:], now: now)

        let handle = try FileHandle(forWritingTo: fixture.transcript)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(tokenCount(input: 160, output: 20, session: "one", at: now).utf8))
        try handle.close()

        let appended = try CodexProjectUsageScanner.scan(
            codexHome: fixture.home.path,
            previousStates: initial.fileStates,
            now: now
        )

        XCTAssertEqual(appended.entries.reduce(0) { $0 + $1.tokenUsage.inputTokens }, 160)
        XCTAssertEqual(appended.entries.reduce(0) { $0 + $1.tokenUsage.outputTokens }, 20)
    }

    func testProjectAggregationSeparatesCodexTokensFromClaudeEstimate() {
        let now = Date()
        let entries = [
            ProjectUsageEntry(
                provider: .codex,
                source: .codexLocalTokens,
                sessionId: "codex-session",
                projectName: "overlay",
                model: nil,
                timestamp: now,
                tokenUsage: TokenUsage(inputTokens: 100, outputTokens: 0, cacheCreationInputTokens: 0, cacheReadInputTokens: 0),
                claudeEstimatedCost: nil
            ),
            ProjectUsageEntry(
                provider: .claudeCode,
                source: .claudeLocalEstimate,
                sessionId: "claude-session",
                projectName: "overlay",
                model: "claude-sonnet-4",
                timestamp: now,
                tokenUsage: TokenUsage(inputTokens: 10, outputTokens: 5, cacheCreationInputTokens: 0, cacheReadInputTokens: 0),
                claudeEstimatedCost: CostBreakdown(inputCost: 1, outputCost: 2, cacheWriteCost: 0, cacheReadCost: 0)
            ),
        ]

        let project = try! XCTUnwrap(UsageCalculator.aggregateProjectUsage(entries: entries, now: now).first)

        XCTAssertEqual(project.tokenUsage.totalTokens, 115)
        XCTAssertEqual(project.sessionCount, 2)
        XCTAssertEqual(project.providers, [.codex, .claudeCode])
        XCTAssertEqual(project.claudeEstimatedCost?.totalCost, 3)
        XCTAssertEqual(project.sources, [.claudeLocalEstimate, .codexLocalTokens])
    }

    private func makeFixture() throws -> (home: URL, transcript: URL) {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-overlay-codex-projects-\(UUID().uuidString)", isDirectory: true)
        let sessions = home.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        return (home, sessions.appendingPathComponent("rollout.jsonl"))
    }

    private func write(_ lines: [String], to url: URL) throws {
        try Data(lines.joined().utf8).write(to: url)
    }

    private func sessionMeta(cwd: String, session: String, at date: Date) -> String {
        "{\"timestamp\":\"\(timestamp(date))\",\"session_id\":\"\(session)\",\"payload\":{\"type\":\"session_meta\",\"cwd\":\"\(cwd)\",\"model\":\"gpt-5\"}}\n"
    }

    private func tokenCount(input: Int, output: Int, session: String, at date: Date) -> String {
        "{\"timestamp\":\"\(timestamp(date))\",\"session_id\":\"\(session)\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"input_tokens\":\(input),\"output_tokens\":\(output)}}}}\n"
    }

    private func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
