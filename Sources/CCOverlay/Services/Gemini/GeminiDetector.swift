import Foundation

enum GeminiDetector {
    /// Auth mode for Gemini CLI
    enum AuthMode: Sendable {
        case apiKey(String)
        case googleOAuth(GoogleAuth)
    }

    /// Google OAuth credentials from ~/.gemini/google_accounts.json
    struct GoogleAuth: Sendable {
        let accessToken: String?
        let refreshToken: String?
        let accountEmail: String?
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

        var googleAuth: GoogleAuth? {
            if case .googleOAuth(let auth) = authMode { return auth }
            return nil
        }
    }

    static func detect(manualAPIKey: String? = nil) -> Detection {
        let binaryPath = findBinary()
        let configPath = findConfigPath()
        let model = readConfiguredModel()

        // Try Google OAuth first, then fall back to API key
        let authMode: AuthMode?
        if let googleAuth = readGoogleAuth() {
            authMode = .googleOAuth(googleAuth)
        } else if let key = findAPIKey(manualKey: manualAPIKey) {
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
            "/opt/homebrew/bin/gemini",
            "/usr/local/bin/gemini",
            "\(home)/.npm-global/bin/gemini",
            "\(home)/.local/bin/gemini",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Scan nvm-installed node versions (GUI apps don't inherit shell PATH)
        if let nvmBinary = findInNvmVersions("gemini", home: home) {
            return nvmBinary
        }

        return resolveFromPATH("gemini")
    }

    /// Search ~/.nvm/versions/node/*/bin/ for a binary (nvm paths aren't in GUI app PATH).
    private static func findInNvmVersions(_ binary: String, home: String) -> String? {
        let nvmDir = "\(home)/.nvm/versions/node"
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) else {
            return nil
        }
        // Sort by semantic version descending so we prefer the latest node version
        for version in versions.sorted(by: semanticVersionDescending) {
            let path = "\(nvmDir)/\(version)/bin/\(binary)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// Compare nvm version directory names (e.g. "v18.20.0", "v9.0.0") descending.
    private static func semanticVersionDescending(_ a: String, _ b: String) -> Bool {
        let partsA = a.drop(while: { !$0.isNumber }).split(separator: ".").compactMap { Int($0) }
        let partsB = b.drop(while: { !$0.isNumber }).split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(partsA.count, partsB.count) {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va != vb { return va > vb }
        }
        return false
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
        let settingsFile = "\(AppConstants.geminiConfigPath)/settings.json"
        if FileManager.default.fileExists(atPath: settingsFile) {
            return settingsFile
        }
        // Also check if the directory itself exists (may have auth but no settings)
        let configDir = AppConstants.geminiConfigPath
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: configDir, isDirectory: &isDir), isDir.boolValue {
            return configDir
        }
        return nil
    }

    // MARK: - Google OAuth Auth (from ~/.gemini/google_accounts.json)

    private static func readGoogleAuth() -> GoogleAuth? {
        let configDir = AppConstants.geminiConfigPath

        // google_accounts.json format: {"active": "email@example.com", "old": [...]}
        let accountsPath = "\(configDir)/google_accounts.json"
        guard let accountsData = FileManager.default.contents(atPath: accountsPath),
              let accountsJSON = try? JSONSerialization.jsonObject(with: accountsData) as? [String: Any]
        else { return nil }

        // Extract active account email
        let email = accountsJSON["active"] as? String

        // Check that oauth_creds.json exists (tokens stored separately)
        let oauthCredsPath = "\(configDir)/oauth_creds.json"
        let hasOAuthCreds = FileManager.default.fileExists(atPath: oauthCredsPath)

        // Need an active account or OAuth creds to consider authenticated
        let hasActiveEmail = email.map { !$0.isEmpty } ?? false
        guard hasActiveEmail || hasOAuthCreds else { return nil }

        return GoogleAuth(
            accessToken: nil, // Not needed — we use telemetry-based monitoring
            refreshToken: nil,
            accountEmail: email
        )
    }

    // MARK: - API Key Detection (priority: env > .env file > settings.json > manual)

    private static func findAPIKey(manualKey: String?) -> String? {
        // 1. Environment variable
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
           !key.isEmpty
        {
            return key
        }

        // 2. .env file in ~/.gemini/
        if let key = parseKeyFromEnvFile("\(AppConstants.geminiConfigPath)/.env", varName: "GEMINI_API_KEY") {
            return key
        }

        // 3. settings.json
        if let key = parseKeyFromSettingsJSON() {
            return key
        }

        // 4. Manual key from app settings
        if let key = manualKey, !key.isEmpty {
            return key
        }

        return nil
    }

    private static func parseKeyFromEnvFile(_ path: String, varName: String) -> String? {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(varName)=") else { continue }
            var value = String(trimmed.dropFirst(varName.count + 1))
                .trimmingCharacters(in: .whitespaces)
            // Remove surrounding quotes
            if (value.hasPrefix("\"") && value.hasSuffix("\""))
                || (value.hasPrefix("'") && value.hasSuffix("'"))
            {
                value = String(value.dropFirst().dropLast())
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func parseKeyFromSettingsJSON() -> String? {
        let path = "\(AppConstants.geminiConfigPath)/settings.json"
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        // Check top-level api_key or nested under "auth"
        if let key = json["api_key"] as? String, !key.isEmpty { return key }
        if let auth = json["auth"] as? [String: Any],
           let key = auth["api_key"] as? String, !key.isEmpty
        { return key }

        return nil
    }

    // MARK: - Model Detection

    private static func readConfiguredModel() -> String? {
        let path = "\(AppConstants.geminiConfigPath)/settings.json"
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return json["model"] as? String
    }
}
