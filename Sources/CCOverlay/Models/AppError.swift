import Foundation

/// Typed errors for the CC-Overlay application with user-friendly messages.
enum AppError: LocalizedError, Equatable {
    case networkUnavailable
    case apiError(statusCode: Int)
    case apiUnauthorized
    case jsonlParseError(file: String)
    case keychainAccessDenied
    case noCredentials
    case historyStorageUnavailable
    case historyEmpty(provider: String)
    case unknown(message: String)

    var errorDescription: String? {
        title
    }

    var title: String {
        switch self {
        case .networkUnavailable:
            return "Network Connection Error"
        case .apiError(let statusCode):
            return "API Error (\(statusCode))"
        case .apiUnauthorized:
            return "Authentication Expired"
        case .jsonlParseError:
            return "Parse Error"
        case .keychainAccessDenied:
            return "Keychain Access Denied"
        case .noCredentials:
            return "No Credentials"
        case .historyStorageUnavailable:
            return "History Storage Unavailable"
        case .historyEmpty:
            return "No History Data"
        case .unknown:
            return "Error"
        }
    }

    var message: String {
        switch self {
        case .networkUnavailable:
            return "Please check your internet connection."
        case .apiError(let statusCode):
            return "Server returned error status (\(statusCode))."
        case .apiUnauthorized:
            return "Session expired. Please re-authenticate in Claude Code."
        case .jsonlParseError(let file):
            return "Failed to parse session file: \(file)"
        case .keychainAccessDenied:
            return "Failed to access stored credentials. Please check Keychain permissions."
        case .noCredentials:
            return "No OAuth credentials found. Please re-authenticate with Claude Code."
        case .historyStorageUnavailable:
            return "History storage is unavailable. Data saving and CSV export are disabled."
        case .historyEmpty(let provider):
            return "No usage records for \(provider). Records will appear here once recent usage is generated."
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
        case .historyStorageUnavailable, .historyEmpty:
            return "tray.full"
        case .unknown:
            return "exclamationmark.triangle"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .apiError, .jsonlParseError:
            return true
        case .apiUnauthorized, .keychainAccessDenied, .noCredentials, .historyStorageUnavailable, .historyEmpty, .unknown:
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
