import Foundation

actor OpenAIAPIService {
    private let baseURL = "https://api.openai.com"
    private var apiKey: String?

    // MARK: - Response Types

    struct BillingInfo: Sendable {
        let planName: String
        let hardLimitUSD: Double
        let softLimitUSD: Double
    }

    struct CreditGrants: Sendable {
        let totalGranted: Double
        let totalUsed: Double
        let totalAvailable: Double
    }

    struct UsageSnapshot: Sendable {
        let billing: BillingInfo
        let credits: CreditGrants?
        let dailyUsageUSD: Double
        let monthlyUsageUSD: Double
        let budgetUtilization: Double    // 0-100
        let remainingBudgetUSD: Double
        let periodEnd: Date?
        let fetchedAt: Date
    }

    // MARK: - Configuration

    func configure(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Fetch

    func fetchUsage() async throws -> UsageSnapshot {
        guard let apiKey else { throw APIError.noAPIKey }

        // Fetch billing subscription and usage in parallel
        async let billingResult = fetchBillingSubscription(apiKey: apiKey)
        async let creditsResult = fetchCreditGrants(apiKey: apiKey)
        async let usageResult = fetchCurrentUsage(apiKey: apiKey)

        let billing = try await billingResult
        let credits = try? await creditsResult
        let (dailyUSD, monthlyUSD, periodEnd) = try await usageResult

        // Calculate budget utilization
        let limit: Double
        let remaining: Double
        let utilization: Double

        if let credits, credits.totalGranted > 0 {
            // Credit-based account
            limit = credits.totalGranted
            remaining = credits.totalAvailable
            utilization = limit > 0 ? min((credits.totalUsed / limit) * 100.0, 100.0) : 0
        } else if billing.hardLimitUSD > 0 {
            // Budget-limited account
            limit = billing.hardLimitUSD
            remaining = max(limit - monthlyUSD, 0)
            utilization = min((monthlyUSD / limit) * 100.0, 100.0)
        } else {
            // No limit set
            remaining = .infinity
            utilization = 0
        }

        return UsageSnapshot(
            billing: billing,
            credits: credits,
            dailyUsageUSD: dailyUSD,
            monthlyUsageUSD: monthlyUSD,
            budgetUtilization: utilization,
            remainingBudgetUSD: remaining,
            periodEnd: periodEnd,
            fetchedAt: Date()
        )
    }

    // MARK: - Billing Subscription

    private func fetchBillingSubscription(apiKey: String) async throws -> BillingInfo {
        let url = URL(string: "\(baseURL)/v1/dashboard/billing/subscription")!
        let data = try await makeRequest(url: url, apiKey: apiKey)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        let planName = json["plan"] as? [String: Any]
        let planTitle = planName?["title"] as? String ?? "Unknown"
        let hardLimit = json["hard_limit_usd"] as? Double ?? 0
        let softLimit = json["soft_limit_usd"] as? Double ?? 0

        return BillingInfo(
            planName: planTitle,
            hardLimitUSD: hardLimit,
            softLimitUSD: softLimit
        )
    }

    // MARK: - Credit Grants

    private func fetchCreditGrants(apiKey: String) async throws -> CreditGrants {
        let url = URL(string: "\(baseURL)/v1/dashboard/billing/credit_grants")!
        let data = try await makeRequest(url: url, apiKey: apiKey)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        let granted = json["total_granted"] as? Double ?? 0
        let used = json["total_used"] as? Double ?? 0
        let available = json["total_available"] as? Double ?? 0

        return CreditGrants(
            totalGranted: granted,
            totalUsed: used,
            totalAvailable: available
        )
    }

    // MARK: - Current Usage

    private func fetchCurrentUsage(apiKey: String) async throws -> (daily: Double, monthly: Double, periodEnd: Date?) {
        // Get current billing period dates
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let startDate = formatter.string(from: startOfMonth)
        let endDate = formatter.string(from: now)

        // Fetch monthly usage
        let monthlyURL = URL(string: "\(baseURL)/v1/dashboard/billing/usage?start_date=\(startDate)&end_date=\(endDate)")!
        let monthlyData = try await makeRequest(url: monthlyURL, apiKey: apiKey)

        guard let monthlyJson = try JSONSerialization.jsonObject(with: monthlyData) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        let totalUsageCents = monthlyJson["total_usage"] as? Double ?? 0
        let monthlyUSD = totalUsageCents / 100.0

        // Calculate daily from daily_costs array
        var dailyUSD = 0.0
        if let dailyCosts = monthlyJson["daily_costs"] as? [[String: Any]] {
            // Last entry is today
            if let todayEntry = dailyCosts.last {
                let lineItems = todayEntry["line_items"] as? [[String: Any]] ?? []
                for item in lineItems {
                    dailyUSD += (item["cost"] as? Double ?? 0) / 100.0
                }
            }
        }

        // Period end: end of current month
        var endComponents = calendar.dateComponents([.year, .month], from: now)
        endComponents.month = (endComponents.month ?? 1) + 1
        endComponents.day = 1
        let periodEnd = calendar.date(from: endComponents)

        return (dailyUSD, monthlyUSD, periodEnd)
    }

    // MARK: - HTTP

    private func makeRequest(url: URL, apiKey: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConstants.apiTimeoutInterval

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        return data
    }

    // MARK: - Errors

    enum APIError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "OpenAI API key not configured"
            case .invalidResponse: return "Invalid OpenAI API response"
            case .httpError(let code): return "OpenAI API error (HTTP \(code))"
            }
        }
    }
}
