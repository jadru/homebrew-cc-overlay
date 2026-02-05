import Foundation

/// Typed errors for the CC-Overlay application with user-friendly messages.
enum AppError: LocalizedError, Equatable {
    case networkUnavailable
    case apiError(statusCode: Int)
    case apiUnauthorized
    case jsonlParseError(file: String)
    case keychainAccessDenied
    case noCredentials
    case unknown(message: String)

    var errorDescription: String? {
        title
    }

    var title: String {
        switch self {
        case .networkUnavailable:
            return "Network Unavailable"
        case .apiError(let statusCode):
            return "API Error (\(statusCode))"
        case .apiUnauthorized:
            return "Unauthorized"
        case .jsonlParseError:
            return "Parse Error"
        case .keychainAccessDenied:
            return "Keychain Access Denied"
        case .noCredentials:
            return "No Credentials"
        case .unknown:
            return "Error"
        }
    }

    var message: String {
        switch self {
        case .networkUnavailable:
            return "Unable to reach Anthropic API. Check your internet connection."
        case .apiError(let statusCode):
            return "The API returned an error with status code \(statusCode)."
        case .apiUnauthorized:
            return "Your session has expired. Please re-authenticate in Claude Code."
        case .jsonlParseError(let file):
            return "Failed to parse session file: \(file)"
        case .keychainAccessDenied:
            return "Unable to access stored credentials. Check Keychain permissions."
        case .noCredentials:
            return "No OAuth credentials found. Use Claude Code to authenticate."
        case .unknown(let msg):
            return msg
        }
    }

    var icon: String {
        switch self {
        case .networkUnavailable:
            return "wifi.slash"
        case .apiError, .apiUnauthorized:
            return "exclamationmark.icloud"
        case .jsonlParseError:
            return "doc.badge.ellipsis"
        case .keychainAccessDenied, .noCredentials:
            return "key.slash"
        case .unknown:
            return "exclamationmark.triangle"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .apiError, .jsonlParseError:
            return true
        case .apiUnauthorized, .keychainAccessDenied, .noCredentials, .unknown:
            return false
        }
    }

    /// Creates an AppError from a string message (for backward compatibility).
    static func from(_ message: String) -> AppError {
        if message.lowercased().contains("network") || message.lowercased().contains("internet") {
            return .networkUnavailable
        }
        if message.lowercased().contains("401") || message.lowercased().contains("unauthorized") {
            return .apiUnauthorized
        }
        if message.lowercased().contains("keychain") {
            return .keychainAccessDenied
        }
        return .unknown(message: message)
    }
}
