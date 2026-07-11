import Foundation

enum CodexDetector {
    /// OAuth tokens from ~/.codex/auth.json. Codex CLI owns refresh and persistence.
    struct ChatGPTAuth: Sendable {
        let accessToken: String
        let accountId: String?
        let planType: String?
    }

    struct Detection: Sendable {
        let binaryPath: String?
        let chatgptAuth: ChatGPTAuth?

        var isAvailable: Bool { binaryPath != nil && chatgptAuth != nil }
    }

    static func detect() -> Detection {
        let binaryPath = findBinary()
        let chatgptAuth = readChatGPTAuth()
        let detection = Detection(binaryPath: binaryPath, chatgptAuth: chatgptAuth)

        DebugFlowLogger.shared.log(
            stage: .detection,
            provider: .codex,
            message: detection.isAvailable ? "detected" : "not-detected",
            details: [
                "binary": binaryPath ?? "<none>",
                "authMode": chatgptAuth == nil ? "none" : "chatgpt-oauth",
            ]
        )

        return detection
    }

    static func findBinary(home: String = FileManager.default.homeDirectoryForCurrentUser.path) -> String? {
        let candidates = [
            "\(home)/Library/Application Support/com.conductor.app/bin/codex",
            "\(home)/.asdf/shims/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.npm/bin/codex",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        if let nvmBinary = CLIBinaryFinder.findInNvmVersions("codex", home: home) {
            return nvmBinary
        }

        return CLIBinaryFinder.resolveFromPATH("codex")
    }

    private static func readChatGPTAuth() -> ChatGPTAuth? {
        let authPath = "\(AppConstants.codexConfigPath)/auth.json"
        guard let data = FileManager.default.contents(atPath: authPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty
        else {
            return nil
        }

        let authMode = json["auth_mode"] as? String
        guard authMode == nil || authMode == "chatgpt" || authMode == "oauth" else {
            return nil
        }

        let accountId = tokens["account_id"] as? String
        let planType = parsePlan(from: tokens["id_token"] as? String)
            ?? parsePlan(from: accessToken)

        return ChatGPTAuth(
            accessToken: accessToken,
            accountId: accountId,
            planType: planType
        )
    }

    private static func parsePlan(from token: String?) -> String? {
        guard let token else { return nil }
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }

        guard let payloadData = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let authClaim = json["https://api.openai.com/auth"] as? [String: Any]
        else {
            return nil
        }
        return authClaim["chatgpt_plan_type"] as? String
    }
}
