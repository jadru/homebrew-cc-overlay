import XCTest
@testable import CCOverlay

final class TerminalLauncherTests: XCTestCase {
    func testShellCommandQuotesProjectDirectory() {
        let command = TerminalLauncher.shellCommand(
            command: "codex",
            workingDirectory: URL(fileURLWithPath: "/tmp/it's ready", isDirectory: true)
        )

        XCTAssertEqual(command, "cd '/tmp/it'\\''s ready' && codex")
    }

    func testITermScriptCreatesATabAndWritesTheCommand() {
        let source = TerminalLauncher.appleScriptSource(
            command: "cd '/tmp/project' && codex",
            terminal: .iTerm
        )

        XCTAssertTrue(source.contains("create tab with default profile"))
        XCTAssertTrue(source.contains("current session of current window to write text"))
        XCTAssertTrue(source.contains("cd '/tmp/project' && codex"))
    }

    func testTerminalScriptEscapesAppleScriptCharacters() {
        let source = TerminalLauncher.appleScriptSource(
            command: "echo \\\"ready\\\" && printf '\\\\n'",
            terminal: .terminal
        )

        XCTAssertTrue(source.contains("echo \\\\\\\"ready\\\\\\\""))
        XCTAssertTrue(source.contains("printf '\\\\\\\\n'"))
    }
}
