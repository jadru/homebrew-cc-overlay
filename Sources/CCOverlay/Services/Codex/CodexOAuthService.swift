import Foundation

/// Fetches Codex usage/rate-limit data using ChatGPT OAuth tokens.
///
/// Endpoint: `GET https://chatgpt.com/backend-api/wham/usage`
/// Auth: `Authorization: Bearer <access_token>`, `chatgpt-account-id: <account_id>`
/// The Codex CLI owns token refresh and writes its own auth file. This service only
/// reads the current credentials and queries the usage endpoint.
actor CodexOAuthService {
    private static let chatgptBaseURL = "https://chatgpt.com/backend-api"

    private var accessToken: String
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

    struct RateLimitResetCredits: Equatable, Sendable {
        let availableCount: Int
        let applicableAvailableCount: Int
        let credits: [ResetCredit]

        init(
            availableCount: Int,
            applicableAvailableCount: Int,
            credits: [ResetCredit] = []
        ) {
            self.availableCount = max(availableCount, 0)
            self.applicableAvailableCount = max(applicableAvailableCount, 0)
            self.credits = credits
        }
    }

    struct ResetCredit: Equatable, Sendable {
        let status: String
        let grantedAt: Date?
        let expiresAt: Date?
    }

    struct UsageSnapshot: Sendable {
        let planType: String
        let primaryWindow: RateLimitWindow?
        let secondaryWindow: RateLimitWindow?
        let credits: CreditInfo?
        let rateLimitResetCredits: RateLimitResetCredits?
        let additionalLimits: [AdditionalLimit]
        let fetchedAt: Date
        let extraUsageEnabled: Bool
    }

    struct AdditionalLimit: Sendable {
        let limitName: String
        let meteredFeature: String?
        let primaryWindow: RateLimitWindow?
    }

    // MARK: - Init

    init(auth: CodexDetector.ChatGPTAuth) {
        self.accessToken = auth.accessToken
        self.accountId = auth.accountId
    }

    func updateAuth(_ auth: CodexDetector.ChatGPTAuth) {
        self.accessToken = auth.accessToken
        self.accountId = auth.accountId
    }

    // MARK: - Fetch Usage

    func fetchUsage() async throws -> UsageSnapshot {
        try await callUsageAPI(token: accessToken)
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

        if httpResponse.statusCode == 429 {
            throw OAuthError.rateLimited(retryAfter: Self.retryAfter(from: httpResponse))
        }

        guard httpResponse.statusCode == 200 else {
            throw OAuthError.httpError(httpResponse.statusCode)
        }

        return try Self.parseUsageResponse(data)
    }

    // MARK: - Parse Response

    nonisolated static func parseUsageResponse(_ data: Data, fetchedAt: Date = Date()) throws -> UsageSnapshot {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OAuthError.invalidResponse
        }

        let planType = json["plan_type"] as? String ?? "unknown"

        guard let rateLimit = json["rate_limit"] as? [String: Any],
              let primaryWindow = parseWindow(rateLimit["primary_window"])
        else {
            throw OAuthError.missingPrimaryRateLimit
        }

        var secondaryWindow: RateLimitWindow?
        secondaryWindow = parseWindow(rateLimit["secondary_window"])

        // Parse credits
        var credits: CreditInfo?
        if let creditsJson = json["credits"] as? [String: Any] {
            credits = CreditInfo(
                hasCredits: creditsJson["has_credits"] as? Bool ?? false,
                unlimited: creditsJson["unlimited"] as? Bool ?? false,
                balance: creditsJson["balance"] as? String
            )
        }

        var rateLimitResetCredits: RateLimitResetCredits?
        if let resetCreditsJson = json["rate_limit_reset_credits"] as? [String: Any] {
            let resetCreditDetails = (resetCreditsJson["credits"] as? [[String: Any]] ?? []).map {
                ResetCredit(
                    status: $0["status"] as? String ?? "available",
                    grantedAt: unixDate($0["granted_at"] ?? $0["grantedAt"]),
                    expiresAt: unixDate($0["expires_at"] ?? $0["expiresAt"])
                )
            }
            rateLimitResetCredits = RateLimitResetCredits(
                availableCount: max(integerValue(resetCreditsJson["available_count"]) ?? 0, 0),
                applicableAvailableCount: max(
                    integerValue(resetCreditsJson["applicable_available_count"]) ?? 0,
                    0
                ),
                credits: resetCreditDetails
            )
        }

        // Parse additional rate limits
        var additionalLimits: [AdditionalLimit] = []
        if let additional = json["additional_rate_limits"] as? [[String: Any]] {
            for item in additional {
                let name = item["limit_name"] as? String ?? item["metered_feature"] as? String ?? "unknown"
                let meteredFeature = item["metered_feature"] as? String
                var limPrimary: RateLimitWindow?
                if let rl = item["rate_limit"] as? [String: Any] {
                    limPrimary = parseWindow(rl["primary_window"])
                }
                additionalLimits.append(AdditionalLimit(
                    limitName: name,
                    meteredFeature: meteredFeature,
                    primaryWindow: limPrimary
                ))
            }
        }

        let extraUsageEnabled = json["extra_usage_enabled"] as? Bool ?? false
        return UsageSnapshot(
            planType: planType,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            credits: credits,
            rateLimitResetCredits: rateLimitResetCredits,
            additionalLimits: additionalLimits,
            fetchedAt: fetchedAt,
            extraUsageEnabled: extraUsageEnabled
        )
    }

    nonisolated private static func parseWindow(_ windowObj: Any?) -> RateLimitWindow? {
        guard let window = windowObj as? [String: Any] else { return nil }
        guard let usedPercent = percentageValue(window["used_percent"]),
              let limitWindowSeconds = integerValue(window["limit_window_seconds"]),
              limitWindowSeconds > 0
        else { return nil }
        return RateLimitWindow(
            usedPercent: usedPercent,
            limitWindowSeconds: limitWindowSeconds,
            resetAfterSeconds: integerValue(window["reset_after_seconds"]) ?? 0,
            resetAt: integerValue(window["reset_at"]) ?? 0
        )
    }

    nonisolated private static func percentageValue(_ value: Any?) -> Int? {
        guard let value = integerValue(value), (0...100).contains(value) else { return nil }
        return value
    }

    nonisolated private static func integerValue(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            return number.intValue
        case let text as String:
            return Int(text)
        default:
            return nil
        }
    }

    nonisolated private static func unixDate(_ value: Any?) -> Date? {
        guard let timestamp = integerValue(value), timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    nonisolated private static func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = TimeInterval(value), seconds >= 0
        else {
            return nil
        }
        return seconds
    }

    // MARK: - Errors

    enum OAuthError: LocalizedError {
        case unauthorized
        case invalidResponse
        case missingPrimaryRateLimit
        case httpError(Int)
        case rateLimited(retryAfter: TimeInterval?)
        case tokenRevoked

        var errorDescription: String? {
            switch self {
            case .unauthorized: return "Codex OAuth token expired"
            case .invalidResponse: return "Invalid Codex API response"
            case .missingPrimaryRateLimit: return "Codex usage response did not include a primary rate limit"
            case .httpError(let code): return "Codex API error (HTTP \(code))"
            case .rateLimited: return "Codex usage refresh is rate limited"
            case .tokenRevoked: return "Codex auth expired. Run 'codex --login' to refresh it."
            }
        }
    }
}
