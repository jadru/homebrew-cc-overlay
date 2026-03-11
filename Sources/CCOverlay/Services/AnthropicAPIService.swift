import Foundation

actor AnthropicAPIService {
    private let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let responseParser = OAuthResponseParser()
    private var cachedCredential: KeychainHelper.OAuthCredential?

    func fetchUsage() async throws -> OAuthUsageStatus {
        let credential = try getCredential()

        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.1.25", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = AppConstants.apiTimeoutInterval

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Token expired or invalid — clear cache and retry once
        if httpResponse.statusCode == 401 {
            cachedCredential = nil
            let freshCredential = try getCredential()
            var retryRequest = request
            retryRequest.setValue("Bearer \(freshCredential.accessToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            guard let retryHttp = retryResponse as? HTTPURLResponse, retryHttp.statusCode == 200 else {
                throw APIError.httpError((retryResponse as? HTTPURLResponse)?.statusCode ?? 0)
            }
            return try parseUsageResponse(retryData, fetchedAt: Date())
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        return try parseUsageResponse(data, fetchedAt: Date())
    }

    func detectedPlanIdentifier() -> String? {
        if let cached = cachedCredential {
            return resolvedPlanIdentifier(from: cached)
        }
        guard let credential = try? KeychainHelper.readClaudeOAuthToken() else { return nil }
        cachedCredential = credential
        return resolvedPlanIdentifier(from: credential)
    }

    /// Read from cache if available and not expired; otherwise read from Keychain.
    private func getCredential() throws -> KeychainHelper.OAuthCredential {
        if let cached = cachedCredential {
            // Re-read from Keychain only if token is expired (5 min buffer)
            if let expiresAt = cached.expiresAt,
               expiresAt.timeIntervalSinceNow < 300
            {
                cachedCredential = nil
            } else {
                return cached
            }
        }

        let credential = try KeychainHelper.readClaudeOAuthToken()
        cachedCredential = credential
        return credential
    }

    private func parseUsageResponse(_ data: Data, fetchedAt: Date) throws -> OAuthUsageStatus {
        try responseParser.parseUsageResponse(data, fetchedAt: fetchedAt)
    }

    private func resolvedPlanIdentifier(from credential: KeychainHelper.OAuthCredential) -> String? {
        let resolved = credential.rateLimitTier ?? credential.subscriptionType
        AppLogger.auth.debug(
            "Plan: tier=\(credential.rateLimitTier ?? "nil"), sub=\(credential.subscriptionType ?? "nil"), resolved=\(resolved ?? "nil")"
        )
        return resolved
    }

    enum APIError: LocalizedError, Equatable {
        case invalidResponse
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid API response"
            case .httpError(let code): return "API error (HTTP \(code))"
            }
        }
    }
}
