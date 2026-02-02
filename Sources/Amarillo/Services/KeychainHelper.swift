import Foundation
import Security

enum KeychainHelper {
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
            kSecAttrService as String: "Claude Code-credentials",
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

    enum KeychainError: LocalizedError {
        case notFound
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .notFound: return "Claude Code credentials not found in Keychain"
            case .invalidFormat: return "Invalid credential format in Keychain"
            }
        }
    }
}
