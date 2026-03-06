import Foundation

enum GeminiDetector {
    /// Auth mode for Gemini CLI
    enum AuthMode: Sendable {
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

        var googleAuth: GoogleAuth? {
            if case .googleOAuth(let auth) = authMode { return auth }
            return nil
        }
    }

    static func detect() -> Detection {
        let binaryPath = findBinary()
        let configPath = findConfigPath()
        let model = readConfiguredModel()

        // Google OAuth only
        let authMode: AuthMode?
        if let googleAuth = readGoogleAuth() {
            authMode = .googleOAuth(googleAuth)
        } else {
            authMode = nil
        }

        let detection = Detection(
            binaryPath: binaryPath,
            configPath: configPath,
            authMode: authMode,
            configuredModel: model
        )

        let authModeLabel = switch authMode {
        case .googleOAuth:
            "google-oauth"
        case nil:
            "none"
        }
        DebugFlowLogger.shared.log(
            stage: .detection,
            provider: .gemini,
            message: detection.isAvailable ? "detected" : "not-detected",
            details: [
                "binary": binaryPath ?? "<none>",
                "configPath": configPath ?? "<none>",
                "model": model ?? "<none>",
                "authMode": authModeLabel,
            ]
        )

        return detection
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
        if let nvmBinary = CLIBinaryFinder.findInNvmVersions("gemini", home: home) {
            return nvmBinary
        }

        return CLIBinaryFinder.resolveFromPATH("gemini")
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

    // MARK: - Model Detection

    private static func readConfiguredModel() -> String? {
        let path = "\(AppConstants.geminiConfigPath)/settings.json"
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return json["model"] as? String
    }
}
