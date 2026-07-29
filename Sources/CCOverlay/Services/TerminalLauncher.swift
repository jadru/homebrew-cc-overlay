import AppKit
import Foundation

@MainActor
enum TerminalLauncher {
    enum LaunchError: LocalizedError {
        case terminalUnavailable(String)
        case scriptFailed(String)

        var errorDescription: String? {
            switch self {
            case .terminalUnavailable(let terminal):
                return "\(terminal) is not installed."
            case .scriptFailed(let message):
                return "Could not start the command: \(message)"
            }
        }
    }

    static func launch(
        provider: CLIProvider,
        workingDirectory: URL,
        terminal: PreferredTerminal
    ) throws {
        try launch(
            command: launchCommand(for: provider),
            workingDirectory: workingDirectory,
            terminal: terminal
        )
    }

    nonisolated static func launchCommand(for provider: CLIProvider) -> String {
        if provider == .codex, let binaryPath = CodexDetector.findBinary() {
            return shellQuote(binaryPath)
        }
        return provider.launchCommand
    }

    static func launch(
        command: String,
        workingDirectory: URL,
        terminal: PreferredTerminal
    ) throws {
        let shellCommand = shellCommand(command: command, workingDirectory: workingDirectory)
        switch terminal {
        case .terminal:
            guard NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.apple.Terminal"
            ) != nil else {
                throw LaunchError.terminalUnavailable(terminal.label)
            }
        case .iTerm:
            guard NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.googlecode.iterm2"
            ) != nil else {
                throw LaunchError.terminalUnavailable(terminal.label)
            }
        }

        let source = appleScriptSource(command: shellCommand, terminal: terminal)
        guard let script = NSAppleScript(source: source) else {
            throw LaunchError.scriptFailed("Could not prepare the terminal automation.")
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "AppleScript failed"
            throw LaunchError.scriptFailed(message)
        }
    }

    static func chooseWorkingDirectory() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Run here"
        panel.message = "Choose the project directory for the new coding session."
        let response = await panel.begin()
        return response == .OK ? panel.url : nil
    }

    nonisolated static func shellCommand(command: String, workingDirectory: URL) -> String {
        "cd \(shellQuote(workingDirectory.path)) && \(command)"
    }

    nonisolated static func appleScriptSource(
        command: String,
        terminal: PreferredTerminal
    ) -> String {
        let escaped = appleScriptQuote(command)
        switch terminal {
        case .terminal:
            return """
            tell application "Terminal"
                activate
                do script "\(escaped)"
            end tell
            """
        case .iTerm:
            return """
            tell application "iTerm"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                else
                    tell current window to create tab with default profile
                end if
                tell current session of current window to write text "\(escaped)"
            end tell
            """
        }
    }

    nonisolated private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    nonisolated private static func appleScriptQuote(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
