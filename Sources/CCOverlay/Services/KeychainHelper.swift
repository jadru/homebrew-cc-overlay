import Foundation
import LocalAuthentication
import Security

enum KeychainHelper {
    private enum Service {
        static let claudeOAuth = "Claude Code-credentials"
    }

    struct OAuthCredential: Sendable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Date?
        let subscriptionType: String?
        let rateLimitTier: String?
    }

    static func readClaudeOAuthToken() throws -> OAuthCredential {
        let authenticationContext = LAContext()
        // Monitoring must never surface a login-password prompt. The user can
        // grant persistent access in Keychain Access when Claude data is needed.
        authenticationContext.interactionNotAllowed = true

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Service.claudeOAuth,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: authenticationContext,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            throw KeychainError.notFound
        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw KeychainError.accessDenied
        default:
            throw KeychainError.operationFailed(status)
        }

        guard let data = result as? Data else {
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
        case accessDenied
        case operationFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .notFound: return "Credential not found in Keychain"
            case .invalidFormat: return "Invalid credential format in Keychain"
            case .accessDenied: return "Keychain access denied — open Keychain Access, find \"Claude Code-credentials\", and allow this app"
            case .operationFailed(let status): return "Keychain operation failed (\(status))"
            }
        }

        var isAccessDenied: Bool {
            if case .accessDenied = self { return true }
            return false
        }
    }
}
