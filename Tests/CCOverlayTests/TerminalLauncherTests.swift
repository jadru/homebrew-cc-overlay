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

    func testCodexProfileLaunchCommandSetsQuotedCodexHome() {
        let command = TerminalLauncher.codexLaunchCommand(
            codexHome: "/Users/tester/Codex Accounts/client's work"
        )

        XCTAssertTrue(command.contains("CODEX_HOME='/Users/tester/Codex Accounts/client'\\''s work'"))
        XCTAssertTrue(command.contains("codex"))
    }

    func testCodexProfileLoginUsesFileCredentialStorage() {
        let command = TerminalLauncher.codexLoginCommand(codexHome: "/Users/tester/.codex-client")

        XCTAssertTrue(command.contains("mkdir -p"))
        XCTAssertTrue(command.contains("CODEX_HOME='/Users/tester/.codex-client'"))
        XCTAssertTrue(command.contains("cli_auth_credentials_store"))
        XCTAssertTrue(command.hasSuffix(" login"))
    }
}
