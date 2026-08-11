import Foundation

enum UpdateLaunchHandoff {
    private static let argumentName = "--update-handoff"

    static func begin() throws -> String {
        let token = UUID().uuidString
        let readyURL = try readyURL(for: token)
        try? FileManager.default.removeItem(at: readyURL)
        return token
    }

    static func acknowledgeLaunchIfRequested(arguments: [String] = CommandLine.arguments) {
        guard let token = token(from: arguments) else { return }

        do {
            let url = try readyURL(for: token)
            try Data(token.utf8).write(to: url, options: .atomic)
        } catch {
            AppLogger.ui.error("Failed to acknowledge updated app launch: \(error.localizedDescription)")
        }
    }

    static func waitForAcknowledgement(token: String, timeout: TimeInterval) -> Bool {
        guard let url = try? readyURL(for: token) else { return false }
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let data = try? Data(contentsOf: url),
               String(decoding: data, as: UTF8.self) == token {
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    static func finish(token: String) {
        guard let url = try? readyURL(for: token) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func token(from arguments: [String]) -> String? {
        guard let argumentIndex = arguments.firstIndex(of: argumentName),
              arguments.indices.contains(argumentIndex + 1),
              let token = UUID(uuidString: arguments[argumentIndex + 1])
        else {
            return nil
        }
        return token.uuidString
    }

    private static func readyURL(for token: String) throws -> URL {
        let appSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupportURL
            .appendingPathComponent("CC-Overlay", isDirectory: true)
            .appendingPathComponent("UpdateHandoffs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(token).ready")
    }
}
