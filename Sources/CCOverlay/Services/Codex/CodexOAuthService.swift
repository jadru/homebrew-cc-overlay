import Foundation

/// Fetches Codex usage/rate-limit data using ChatGPT OAuth tokens.
///
/// Endpoint: `GET https://chatgpt.com/backend-api/wham/usage`
/// Auth: `Authorization: Bearer <access_token>`, `chatgpt-account-id: <account_id>`
/// Token refresh: `POST https://auth.openai.com/oauth/token`
actor CodexOAuthService {
    private static let chatgptBaseURL = "https://chatgpt.com/backend-api"
    private static let refreshTokenURL = "https://auth.openai.com/oauth/token"
    private static let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"

    private var accessToken: String
    private var refreshToken: String
    private var accountId: String?

    // MARK: - Response Types

    struct RateLimitWindow: Sendable {
        let usedPercent: Int
        let limitWindowSeconds: Int
        let resetAfterSeconds: Int
        let resetAt: Int // Unix timestamp
    }

    struct CreditInfo: Sendable {
        let hasCredits: Bool
        let unlimited: Bool
        let balance: String?
    }

    struct UsageSnapshot: Sendable {
        let planType: String
        let primaryWindow: RateLimitWindow?
        let secondaryWindow: RateLimitWindow?
        let credits: CreditInfo?
        let additionalLimits: [AdditionalLimit]
        let fetchedAt: Date
        let extraUsageEnabled: Bool
        let rawKeys: [String]
    }

    struct AdditionalLimit: Sendable {
        let limitName: String
        let primaryWindow: RateLimitWindow?
    }

    // MARK: - Init

    init(auth: CodexDetector.ChatGPTAuth) {
        self.accessToken = auth.accessToken
        self.refreshToken = auth.refreshToken
        self.accountId = auth.accountId
    }

    func updateAuth(_ auth: CodexDetector.ChatGPTAuth) {
        self.accessToken = auth.accessToken
        self.refreshToken = auth.refreshToken
        self.accountId = auth.accountId
    }

    // MARK: - JWT Expiry Check

    /// Check if the current access token is likely expired by parsing its JWT `exp` claim.
    /// Returns true if expired, within 60s of expiry, or if the token can't be parsed.
    private func isTokenLikelyExpired() -> Bool {
        let parts = accessToken.split(separator: ".")
        guard parts.count >= 2 else { return true }

        var base64 = String(parts[1])
        while base64.count % 4 != 0 { base64.append("=") }

        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval
        else { return true }

        return Date().timeIntervalSince1970 >= (exp - 60)
    }

    // MARK: - Fetch Usage

    func fetchUsage() async throws -> UsageSnapshot {
        // Proactively refresh if token is stale
        if isTokenLikelyExpired() {
            try await refreshAccessToken()
        }

        do {
            return try await callUsageAPI(token: accessToken)
        } catch OAuthError.unauthorized {
            // Token rejected — try one more refresh + retry
            try await refreshAccessToken()
            return try await callUsageAPI(token: accessToken)
        } catch OAuthError.httpError(let code) where [429, 500, 502, 503].contains(code) {
            // Transient error — retry once after delay
            try await Task.sleep(for: .seconds(2))
            return try await callUsageAPI(token: accessToken)
        }
    }

    private func callUsageAPI(token: String) async throws -> UsageSnapshot {
        let url = URL(string: "\(Self.chatgptBaseURL)/wham/usage")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accountId {
            request.setValue(accountId, forHTTPHeaderField: "chatgpt-account-id")
        }
        request.timeoutInterval = AppConstants.oauthTimeoutInterval

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw OAuthError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw OAuthError.httpError(httpResponse.statusCode)
        }

        return try parseUsageResponse(data)
    }

    // MARK: - Parse Response

    private func parseUsageResponse(_ data: Data) throws -> UsageSnapshot {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OAuthError.invalidResponse
        }

        let planType = json["plan_type"] as? String ?? "unknown"

        // Parse rate_limit
        var primaryWindow: RateLimitWindow?
        var secondaryWindow: RateLimitWindow?

        if let rateLimit = json["rate_limit"] as? [String: Any] {
            primaryWindow = parseWindow(rateLimit["primary_window"])
            secondaryWindow = parseWindow(rateLimit["secondary_window"])
        }

        // Parse credits
        var credits: CreditInfo?
        if let creditsJson = json["credits"] as? [String: Any] {
            credits = CreditInfo(
                hasCredits: creditsJson["has_credits"] as? Bool ?? false,
                unlimited: creditsJson["unlimited"] as? Bool ?? false,
                balance: creditsJson["balance"] as? String
            )
        }

        // Parse additional rate limits
        var additionalLimits: [AdditionalLimit] = []
        if let additional = json["additional_rate_limits"] as? [[String: Any]] {
            for item in additional {
                let name = item["limit_name"] as? String ?? item["metered_feature"] as? String ?? "unknown"
                var limPrimary: RateLimitWindow?
                if let rl = item["rate_limit"] as? [String: Any] {
                    limPrimary = parseWindow(rl["primary_window"])
                }
                additionalLimits.append(AdditionalLimit(limitName: name, primaryWindow: limPrimary))
            }
        }

        let extraUsageEnabled = json["extra_usage_enabled"] as? Bool ?? false
        let rawKeys = Array(json.keys).sorted()

        return UsageSnapshot(
            planType: planType,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            credits: credits,
            additionalLimits: additionalLimits,
            fetchedAt: Date(),
            extraUsageEnabled: extraUsageEnabled,
            rawKeys: rawKeys
        )
    }

    private func parseWindow(_ windowObj: Any?) -> RateLimitWindow? {
        guard let window = windowObj as? [String: Any] else { return nil }
        guard let usedPercent = window["used_percent"] as? Int else { return nil }
        return RateLimitWindow(
            usedPercent: usedPercent,
            limitWindowSeconds: window["limit_window_seconds"] as? Int ?? 0,
            resetAfterSeconds: window["reset_after_seconds"] as? Int ?? 0,
            resetAt: window["reset_at"] as? Int ?? 0
        )
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async throws {
        let url = URL(string: Self.refreshTokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConstants.apiTimeoutInterval

        let body: [String: String] = [
            "client_id": Self.clientId,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "scope": "openid profile email offline_access",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.refreshFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                throw OAuthError.tokenRevoked
            }
            throw OAuthError.refreshFailed("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String
        else {
            throw OAuthError.refreshFailed("Missing access_token")
        }

        self.accessToken = newAccessToken
        if let newRefreshToken = json["refresh_token"] as? String {
            self.refreshToken = newRefreshToken
        }

        // Persist refreshed tokens back to auth.json
        persistRefreshedTokens(accessToken: newAccessToken, refreshToken: json["refresh_token"] as? String)
    }

    private func persistRefreshedTokens(accessToken: String, refreshToken: String?) {
        let authPath = "\(AppConstants.codexConfigPath)/auth.json"
        guard let data = FileManager.default.contents(atPath: authPath),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var tokens = json["tokens"] as? [String: Any]
        else { return }

        tokens["access_token"] = accessToken
        if let refreshToken {
            tokens["refresh_token"] = refreshToken
        }
        json["tokens"] = tokens

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        json["last_refresh"] = formatter.string(from: Date())

        guard let updatedData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? updatedData.write(to: URL(fileURLWithPath: authPath), options: .atomic)
    }

    // MARK: - Errors

    enum OAuthError: LocalizedError {
        case unauthorized
        case invalidResponse
        case httpError(Int)
        case refreshFailed(String)
        case tokenRevoked

        var errorDescription: String? {
            switch self {
            case .unauthorized: return "Codex OAuth token expired"
            case .invalidResponse: return "Invalid Codex API response"
            case .httpError(let code): return "Codex API error (HTTP \(code))"
            case .refreshFailed(let reason): return "Token refresh failed: \(reason)"
            case .tokenRevoked: return "Codex auth revoked. Run 'codex --login' to re-authenticate."
            }
        }
    }
}
