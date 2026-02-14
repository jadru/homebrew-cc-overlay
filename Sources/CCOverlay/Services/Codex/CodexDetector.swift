import Foundation

enum CodexDetector {
    /// Auth mode for Codex
    enum AuthMode: Sendable {
        case apiKey(String)
        case chatgpt(ChatGPTAuth)
    }

    /// OAuth tokens from ~/.codex/auth.json
    struct ChatGPTAuth: Sendable {
        let accessToken: String
        let refreshToken: String
        let accountId: String?
        let planType: String?
        let lastRefresh: Date?
    }

    struct Detection: Sendable {
        let binaryPath: String?
        let configPath: String?
        let authMode: AuthMode?
        let configuredModel: String?

        var isAvailable: Bool { binaryPath != nil && authMode != nil }

        var apiKey: String? {
            if case .apiKey(let key) = authMode { return key }
            return nil
        }

        var chatgptAuth: ChatGPTAuth? {
            if case .chatgpt(let auth) = authMode { return auth }
            return nil
        }
    }

    static func detect(manualAPIKey: String? = nil) -> Detection {
        let binaryPath = findBinary()
        let configPath = findConfigPath()
        let model = configPath.flatMap { parseModel(from: $0) }

        // Try OAuth first (from ~/.codex/auth.json), then fall back to API key
        let authMode: AuthMode?
        if let chatgptAuth = readChatGPTAuth() {
            authMode = .chatgpt(chatgptAuth)
        } else if let key = findAPIKey(configPath: configPath, manualKey: manualAPIKey) {
            authMode = .apiKey(key)
        } else {
            authMode = nil
        }

        return Detection(
            binaryPath: binaryPath,
            configPath: configPath,
            authMode: authMode,
            configuredModel: model
        )
    }

    // MARK: - Binary Detection

    private static func findBinary() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.npm/bin/codex",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return resolveFromPATH("codex")
    }

    private static func resolveFromPATH(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return result?.isEmpty == false ? result : nil
        } catch {
            return nil
        }
    }

    // MARK: - Config Path

    private static func findConfigPath() -> String? {
        let configDir = AppConstants.codexConfigPath
        let configFile = "\(configDir)/config.toml"
        if FileManager.default.fileExists(atPath: configFile) {
            return configFile
        }
        return nil
    }

    // MARK: - ChatGPT OAuth Auth (from ~/.codex/auth.json)

    private static func readChatGPTAuth() -> ChatGPTAuth? {
        let authPath = "\(AppConstants.codexConfigPath)/auth.json"
        guard let data = FileManager.default.contents(atPath: authPath) else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Accept "chatgpt", "oauth", or any auth.json with valid tokens
        let authModeStr = json["auth_mode"] as? String
        guard authModeStr == "chatgpt" || authModeStr == "oauth" || json["tokens"] is [String: Any] else {
            return nil
        }

        guard let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty,
              let refreshToken = tokens["refresh_token"] as? String,
              !refreshToken.isEmpty
        else { return nil }

        let accountId = tokens["account_id"] as? String

        // Parse plan type from id_token JWT, fallback to access_token JWT
        let planType = parsePlanFromIdToken(tokens["id_token"] as? String)
            ?? parsePlanFromIdToken(accessToken)

        // Parse last_refresh date
        var lastRefresh: Date?
        if let refreshStr = json["last_refresh"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            lastRefresh = formatter.date(from: refreshStr)
        }

        return ChatGPTAuth(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accountId: accountId,
            planType: planType,
            lastRefresh: lastRefresh
        )
    }

    /// Decode the JWT id_token payload to extract chatgpt_plan_type
    private static func parsePlanFromIdToken(_ idToken: String?) -> String? {
        guard let idToken else { return nil }

        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var base64 = String(parts[1])
        // Pad base64 to 4-char boundary
        while base64.count % 4 != 0 { base64.append("=") }

        guard let payloadData = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else { return nil }

        // Look in the nested auth claim
        if let authClaim = payload["https://api.openai.com/auth"] as? [String: Any],
           let planType = authClaim["chatgpt_plan_type"] as? String
        {
            return planType
        }
        return nil
    }

    // MARK: - API Key Detection (priority: env > config.toml > manual)

    private static func findAPIKey(configPath: String?, manualKey: String?) -> String? {
        // 1. Environment variable
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !key.isEmpty, key.hasPrefix("sk-")
        {
            return key
        }

        // 2. Parse from config.toml
        if let path = configPath, let key = parseAPIKey(from: path) {
            return key
        }

        // 3. Manual key from settings
        if let key = manualKey, !key.isEmpty, key.hasPrefix("sk-") {
            return key
        }

        return nil
    }

    // MARK: - TOML Parsing (lightweight, line-based)

    private static func parseModel(from configPath: String) -> String? {
        return parseTOMLValue(key: "model", from: configPath)
    }

    private static func parseAPIKey(from configPath: String) -> String? {
        guard let key = parseTOMLValue(key: "api_key", from: configPath),
              key.hasPrefix("sk-")
        else { return nil }
        return key
    }

    private static func parseTOMLValue(key: String, from path: String) -> String? {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        // Simple line-by-line parser for `key = "value"` or `key = 'value'`
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), !trimmed.hasPrefix("[") else { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let k = parts[0].trimmingCharacters(in: .whitespaces)
            guard k == key else { continue }

            var v = parts[1].trimmingCharacters(in: .whitespaces)
            // Remove surrounding quotes
            if (v.hasPrefix("\"") && v.hasSuffix("\"")) || (v.hasPrefix("'") && v.hasSuffix("'")) {
                v = String(v.dropFirst().dropLast())
            }
            return v.isEmpty ? nil : v
        }
        return nil
    }
}
