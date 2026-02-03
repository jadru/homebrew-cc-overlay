import Testing
import Foundation
@testable import CCOverlay

@Suite("SessionMonitor Tests")
@MainActor
struct SessionMonitorTests {

    // MARK: - Process Line Parsing

    @Test("Parse claude process with --resume flag")
    func parseWithResumeFlag() {
        let line = " 5304  1001 Mon Feb  2 20:54:25 2026 /Users/jadru/Library/Application Support/com.conductor.app/bin/claude --resume e7580fb7-4a3c-478b-a589-aac8767bc366 --verbose --output-format stream-json --model opus --permission-mode default"
        let proc = SessionMonitor.parseProcessLine(line)
        #expect(proc != nil)
        #expect(proc?.pid == 5304)
        #expect(proc?.ppid == 1001)
        #expect(proc?.sessionId == "e7580fb7-4a3c-478b-a589-aac8767bc366")
        #expect(proc?.model == "opus")
        #expect(proc?.permissionMode == "default")
    }

    @Test("Parse claude process without --resume flag")
    func parseWithoutResumeFlag() {
        let line = "90897  1001 Mon Feb  2 21:17:08 2026 /Users/jadru/Library/Application Support/com.conductor.app/bin/claude --verbose --output-format stream-json --model opus --permission-mode plan"
        let proc = SessionMonitor.parseProcessLine(line)
        #expect(proc != nil)
        #expect(proc?.pid == 90897)
        #expect(proc?.ppid == 1001)
        #expect(proc?.sessionId == nil)
        #expect(proc?.model == "opus")
        #expect(proc?.permissionMode == "plan")
    }

    @Test("Ignore non-claude processes")
    func ignoreNonClaude() {
        let line = "12345  1001 Mon Feb  2 21:17:08 2026 /usr/bin/vim somefile.txt"
        let proc = SessionMonitor.parseProcessLine(line)
        #expect(proc == nil)
    }

    @Test("Ignore grep processes")
    func ignoreGrepProcesses() {
        let line = "99999  1001 Mon Feb  2 21:17:08 2026 grep --color=auto claude"
        let proc = SessionMonitor.parseProcessLine(line)
        #expect(proc == nil)
    }

    @Test("Parse empty line returns nil")
    func parseEmptyLine() {
        #expect(SessionMonitor.parseProcessLine("") == nil)
        #expect(SessionMonitor.parseProcessLine("   ") == nil)
    }

    @Test("Parse multiple process lines")
    func parseMultipleLines() {
        let output = """
          PID  PPID STARTED                        COMMAND
         5304  1001 Mon Feb  2 20:54:25 2026 /Users/jadru/Library/Application Support/com.conductor.app/bin/claude --resume abc-123 --model opus --permission-mode default
        90897  1001 Mon Feb  2 21:17:08 2026 /Users/jadru/Library/Application Support/com.conductor.app/bin/claude --model sonnet --permission-mode plan
        12345  1001 Mon Feb  2 21:17:08 2026 /usr/bin/vim
        """
        let procs = SessionMonitor.parseProcessOutput(output)
        #expect(procs.count == 2)
        #expect(procs[0].pid == 5304)
        #expect(procs[0].sessionId == "abc-123")
        #expect(procs[1].pid == 90897)
        #expect(procs[1].sessionId == nil)
    }

    // MARK: - Flag Extraction

    @Test("Extract flag value")
    func extractFlag() {
        let cmd = "--verbose --model opus --permission-mode plan"
        #expect(SessionMonitor.extractFlag("--model", from: cmd) == "opus")
        #expect(SessionMonitor.extractFlag("--permission-mode", from: cmd) == "plan")
        #expect(SessionMonitor.extractFlag("--resume", from: cmd) == nil)
    }

    @Test("Extract flag at end of command does not exist")
    func extractFlagAtEnd() {
        let cmd = "--verbose --model"
        #expect(SessionMonitor.extractFlag("--model", from: cmd) == nil)
    }

    @Test("Extract flag ignores flag-like values")
    func extractFlagSkipsFlags() {
        let cmd = "--resume --model opus"
        #expect(SessionMonitor.extractFlag("--resume", from: cmd) == nil)
    }

    // MARK: - lstart Date Parsing

    @Test("Parse lstart date format")
    func parseLstartDate() {
        let date = SessionMonitor.parseLstartFromRest("Mon Feb  2 20:54:25 2026 /some/command")
        #expect(date != nil)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        #expect(components.year == 2026)
        #expect(components.month == 2)
        #expect(components.day == 2)
    }

    @Test("Parse lstart with double-digit day")
    func parseLstartDoubleDigitDay() {
        let date = SessionMonitor.parseLstartFromRest("Wed Jan 15 09:30:00 2026 /some/command")
        #expect(date != nil)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date!)
        #expect(components.day == 15)
    }

    // MARK: - PPID Map

    @Test("Build PPID map from ps output")
    func buildPpidMap() {
        let output = """
          PID  PPID STARTED                        COMMAND
            1     0 Mon Feb  2 08:00:00 2026 /sbin/launchd
          100     1 Mon Feb  2 08:00:01 2026 /Applications/Terminal.app/Contents/MacOS/Terminal
          200   100 Mon Feb  2 08:00:02 2026 /bin/zsh
          300   200 Mon Feb  2 08:00:03 2026 /usr/bin/claude --model opus
        """
        let map = SessionMonitor.buildPpidMap(output)
        #expect(map[1] == 0)
        #expect(map[100] == 1)
        #expect(map[200] == 100)
        #expect(map[300] == 200)
    }

    // MARK: - SessionIndexFile Decoding

    @Test("Decode sessions-index.json")
    func decodeSessionIndex() throws {
        let json = """
        {
          "version": 1,
          "entries": [{
            "sessionId": "abc-123",
            "fullPath": "/path/to/abc-123.jsonl",
            "fileMtime": 1770034631000,
            "messageCount": 22,
            "created": "2026-02-02T11:55:54.451Z",
            "modified": "2026-02-02T12:17:10.532Z",
            "gitBranch": "main",
            "projectPath": "/Users/test/myproject",
            "isSidechain": false
          }],
          "originalPath": "/Users/test/myproject"
        }
        """.data(using: .utf8)!

        let index = try JSONDecoder().decode(SessionIndexFile.self, from: json)
        #expect(index.version == 1)
        #expect(index.entries.count == 1)
        #expect(index.entries[0].sessionId == "abc-123")
        #expect(index.entries[0].messageCount == 22)
        #expect(index.entries[0].gitBranch == "main")
        #expect(index.entries[0].projectPath == "/Users/test/myproject")
        #expect(index.entries[0].isSidechain == false)
        #expect(index.originalPath == "/Users/test/myproject")
    }

    @Test("Decode session index with minimal fields")
    func decodeMinimalSessionIndex() throws {
        let json = """
        {
          "version": 1,
          "entries": [{
            "sessionId": "xyz",
            "fullPath": "/path/to/xyz.jsonl"
          }],
          "originalPath": null
        }
        """.data(using: .utf8)!

        let index = try JSONDecoder().decode(SessionIndexFile.self, from: json)
        #expect(index.entries[0].sessionId == "xyz")
        #expect(index.entries[0].messageCount == nil)
        #expect(index.entries[0].gitBranch == nil)
        #expect(index.entries[0].isSidechain == nil)
    }

    // MARK: - ActiveSession Model

    @Test("Duration calculation")
    func durationCalculation() {
        let session = ActiveSession(
            id: "test",
            pid: 1234,
            processStartTime: Date().addingTimeInterval(-300),
            projectPath: "/Users/test/myproject",
            projectName: "myproject",
            gitBranch: "main",
            messageCount: 10,
            lastModified: nil,
            model: "opus",
            permissionMode: "default",
            isSidechain: false,
            parentAppBundleId: "com.apple.Terminal",
            parentAppName: "Terminal"
        )
        #expect(abs(session.duration - 300) < 2.0)
        #expect(session.displayName == "myproject")
    }

    @Test("Display name fallback when projectName is nil")
    func displayNameFallback() {
        let session = ActiveSession(
            id: "test",
            pid: 1234,
            processStartTime: Date(),
            projectPath: nil,
            projectName: nil,
            gitBranch: nil,
            messageCount: nil,
            lastModified: nil,
            model: nil,
            permissionMode: nil,
            isSidechain: false,
            parentAppBundleId: nil,
            parentAppName: nil
        )
        #expect(session.displayName == "Unknown Project")
    }
}
