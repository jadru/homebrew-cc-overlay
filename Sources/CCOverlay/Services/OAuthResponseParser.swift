import Foundation

struct OAuthResponseParser {
    private static let nestedPayloadKeys = ["quotas", "usage", "rate_limits", "data"]

    func parseUsageResponse(_ data: Data, fetchedAt: Date) throws -> OAuthUsageStatus {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AnthropicAPIService.APIError.invalidResponse
        }

        let topLevelKeys = json.keys.sorted().joined(separator: ", ")
        AppLogger.network.debug("OAuth usage keys: \(topLevelKeys)")

        let effectiveJSON = effectivePayload(from: json)
        let fiveHour = parseBucket(effectiveJSON["five_hour"], label: "five_hour")
        let sevenDay = parseBucket(effectiveJSON["seven_day"], label: "seven_day")

        let sevenDaySonnet: UsageBucket?
        if let sonnetValue = effectiveJSON["seven_day_sonnet"] {
            sevenDaySonnet = parseBucket(sonnetValue, label: "seven_day_sonnet")
        } else {
            sevenDaySonnet = nil
        }

        let extraUsageEnabled: Bool
        if let extraDict = effectiveJSON["extra_usage"] as? [String: Any] {
            extraUsageEnabled = extraDict["is_enabled"] as? Bool ?? false
        } else {
            extraUsageEnabled = false
        }

        let usage = OAuthUsageStatus(
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            sevenDaySonnet: sevenDaySonnet,
            extraUsageEnabled: extraUsageEnabled,
            enterpriseQuota: parseEnterpriseQuota(effectiveJSON["enterprise"]),
            fetchedAt: fetchedAt
        )
        logSuspiciousZeroState(for: usage)
        return usage
    }

    private func effectivePayload(from json: [String: Any]) -> [String: Any] {
        if json["five_hour"] != nil {
            return json
        }

        for key in Self.nestedPayloadKeys {
            guard let nested = json[key] as? [String: Any], nested["five_hour"] != nil else { continue }
            AppLogger.network.debug("OAuth usage payload nested under \(key)")
            return nested
        }

        return json
    }

    private func parseBucket(_ value: Any?, label: String) -> UsageBucket {
        guard let dict = value as? [String: Any] else {
            AppLogger.network.debug("parseBucket(\(label)): nil or wrong type")
            return .zero
        }

        let utilization = parseDouble(dict["utilization"]) ?? 0
        let resetsAt = dict["resets_at"].flatMap { DateParsing.parseISO8601(($0 as? String) ?? "") }
        return UsageBucket(utilization: utilization, resetsAt: resetsAt)
    }

    private func parseEnterpriseQuota(_ value: Any?) -> EnterpriseQuota? {
        guard let dict = value as? [String: Any] else { return nil }

        let orgName = dict["organization_name"] as? String
        let seatTierRaw = dict["seat_tier"] as? String ?? "unknown"
        let seatTier = EnterpriseSeatTier(rawValue: seatTierRaw) ?? .unknown

        return EnterpriseQuota(
            organizationName: orgName,
            seatTier: seatTier,
            organizationLimit: parseSpendingLimit(dict["organization_limit"]),
            seatTierLimit: parseSpendingLimit(dict["seat_tier_limit"]),
            individualLimit: parseSpendingLimit(dict["individual_limit"])
        )
    }

    private func parseSpendingLimit(_ value: Any?) -> SpendingLimit {
        guard let dict = value as? [String: Any] else { return .zero }

        let cap = parseDouble(dict["cap_dollars"]) ?? 0
        let used = parseDouble(dict["used_dollars"]) ?? 0
        let period = (dict["period"] as? String)?.capitalized ?? "Monthly"
        let resetsAt = dict["resets_at"].flatMap { DateParsing.parseISO8601(($0 as? String) ?? "") }

        return SpendingLimit(
            capDollars: cap,
            usedDollars: used,
            periodLabel: period,
            resetsAt: resetsAt
        )
    }

    private func parseDouble(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private func logSuspiciousZeroState(for usage: OAuthUsageStatus) {
        let primaryBucketsAreZero =
            usage.fiveHour.utilization == 0 &&
            usage.fiveHour.resetsAt == nil &&
            usage.sevenDay.utilization == 0 &&
            usage.sevenDay.resetsAt == nil

        let sonnetIsZeroOrMissing =
            usage.sevenDaySonnet == nil ||
            (usage.sevenDaySonnet?.utilization == 0 && usage.sevenDaySonnet?.resetsAt == nil)

        guard primaryBucketsAreZero, sonnetIsZeroOrMissing else { return }
        AppLogger.network.warning("OAuth usage parsed with only zeroed buckets; response shape may have changed")
    }
}
