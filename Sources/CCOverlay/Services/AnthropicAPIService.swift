import Foundation

actor AnthropicAPIService {
    private let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
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

    func detectedSubscriptionType() -> String? {
        if let cached = cachedCredential { return cached.subscriptionType }
        guard let credential = try? KeychainHelper.readClaudeOAuthToken() else { return nil }
        cachedCredential = credential
        return credential.subscriptionType
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
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        let fiveHour = parseBucket(json["five_hour"])
        let sevenDay = parseBucket(json["seven_day"])

        let sevenDaySonnet: UsageBucket?
        if let sonnetDict = json["seven_day_sonnet"] {
            sevenDaySonnet = parseBucket(sonnetDict)
        } else {
            sevenDaySonnet = nil
        }

        let extraUsageEnabled: Bool
        if let extraDict = json["extra_usage"] as? [String: Any] {
            extraUsageEnabled = extraDict["is_enabled"] as? Bool ?? false
        } else {
            extraUsageEnabled = false
        }

        let enterpriseQuota = parseEnterpriseQuota(json["enterprise"])

        return OAuthUsageStatus(
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            sevenDaySonnet: sevenDaySonnet,
            extraUsageEnabled: extraUsageEnabled,
            enterpriseQuota: enterpriseQuota,
            fetchedAt: fetchedAt
        )
    }

    nonisolated private func parseBucket(_ value: Any?) -> UsageBucket {
        guard let dict = value as? [String: Any] else { return .zero }

        let utilization = dict["utilization"] as? Double ?? 0
        let resetsAt: Date? = {
            guard let str = dict["resets_at"] as? String else { return nil }
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fmt.date(from: str) { return date }
            fmt.formatOptions = [.withInternetDateTime]
            return fmt.date(from: str)
        }()

        return UsageBucket(utilization: utilization, resetsAt: resetsAt)
    }

    nonisolated private func parseEnterpriseQuota(_ value: Any?) -> EnterpriseQuota? {
        guard let dict = value as? [String: Any] else { return nil }

        let orgName = dict["organization_name"] as? String
        let seatTierRaw = dict["seat_tier"] as? String ?? "unknown"
        let seatTier = EnterpriseSeatTier(rawValue: seatTierRaw) ?? .unknown

        let orgLimit = parseSpendingLimit(dict["organization_limit"])
        let tierLimit = parseSpendingLimit(dict["seat_tier_limit"])
        let individualLimit = parseSpendingLimit(dict["individual_limit"])

        return EnterpriseQuota(
            organizationName: orgName,
            seatTier: seatTier,
            organizationLimit: orgLimit,
            seatTierLimit: tierLimit,
            individualLimit: individualLimit
        )
    }

    nonisolated private func parseSpendingLimit(_ value: Any?) -> SpendingLimit {
        guard let dict = value as? [String: Any] else { return .zero }

        let cap = dict["cap_dollars"] as? Double ?? 0
        let used = dict["used_dollars"] as? Double ?? 0
        let period = (dict["period"] as? String)?.capitalized ?? "Monthly"

        let resetsAt: Date? = {
            guard let str = dict["resets_at"] as? String else { return nil }
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fmt.date(from: str) { return date }
            fmt.formatOptions = [.withInternetDateTime]
            return fmt.date(from: str)
        }()

        return SpendingLimit(
            capDollars: cap,
            usedDollars: used,
            periodLabel: period,
            resetsAt: resetsAt
        )
    }

    enum APIError: LocalizedError {
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
