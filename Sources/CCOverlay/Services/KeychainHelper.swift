import Foundation
import Security

enum KeychainHelper {
    private enum Service {
        static let claudeOAuth = "Claude Code-credentials"
        static let codexAPIKey = "cc-overlay.codex.api-key"
        static let geminiAPIKey = "cc-overlay.gemini.api-key"
    }

    private enum Account {
        static let apiKey = "api-key"
    }

    struct OAuthCredential: Sendable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Date?
        let subscriptionType: String?
        let rateLimitTier: String?
    }

    static func readClaudeOAuthToken() throws -> OAuthCredential {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Service.claudeOAuth,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.notFound
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauthDict = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauthDict["accessToken"] as? String
        else {
            throw KeychainError.invalidFormat
        }

        let refreshToken = oauthDict["refreshToken"] as? String
        let expiresAt: Date? = {
            guard let ms = oauthDict["expiresAt"] as? Double else { return nil }
            return Date(timeIntervalSince1970: ms / 1000.0)
        }()
        let subscriptionType = oauthDict["subscriptionType"] as? String
        let rateLimitTier = oauthDict["rateLimitTier"] as? String

        return OAuthCredential(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            subscriptionType: subscriptionType,
            rateLimitTier: rateLimitTier
        )
    }

    static func readCodexAPIKey() -> String? {
        try? readSecret(service: Service.codexAPIKey, account: Account.apiKey)
    }

    static func saveCodexAPIKey(_ apiKey: String) throws {
        try saveSecret(apiKey, service: Service.codexAPIKey, account: Account.apiKey)
    }

    static func deleteCodexAPIKey() throws {
        try deleteSecret(service: Service.codexAPIKey, account: Account.apiKey)
    }

    static func readGeminiAPIKey() -> String? {
        try? readSecret(service: Service.geminiAPIKey, account: Account.apiKey)
    }

    static func saveGeminiAPIKey(_ apiKey: String) throws {
        try saveSecret(apiKey, service: Service.geminiAPIKey, account: Account.apiKey)
    }

    static func deleteGeminiAPIKey() throws {
        try deleteSecret(service: Service.geminiAPIKey, account: Account.apiKey)
    }

    private static func readSecret(service: String, account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw KeychainError.notFound
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.operationFailed(status)
        }
        guard let value = String(data: data, encoding: .utf8), !value.isEmpty else {
            throw KeychainError.invalidFormat
        }
        return value
    }

    private static func saveSecret(_ value: String, service: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.operationFailed(addStatus)
            }
            return
        }

        guard updateStatus == errSecSuccess else {
            throw KeychainError.operationFailed(updateStatus)
        }
    }

    private static func deleteSecret(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.operationFailed(status)
        }
    }

    enum KeychainError: LocalizedError {
        case notFound
        case invalidFormat
        case operationFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .notFound: return "Credential not found in Keychain"
            case .invalidFormat: return "Invalid credential format in Keychain"
            case .operationFailed(let status): return "Keychain operation failed (\(status))"
            }
        }
    }
}
