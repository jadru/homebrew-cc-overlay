import Foundation

struct CodexAccountProfile: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var displayName: String
    var codexHome: String
    var isEnabled: Bool
    var sortOrder: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        codexHome: String,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.codexHome = codexHome
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    static func normalizedCodexHome(_ path: String, userHome: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded: String
        if trimmed == "~" {
            expanded = userHome
        } else if trimmed.hasPrefix("~/") {
            expanded = userHome + String(trimmed.dropFirst())
        } else {
            expanded = trimmed
        }
        return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL.path
    }
}

struct CodexAccountRateWindow: Equatable, Sendable {
    let usedPercent: Double
    let windowDurationMinutes: Int
    let resetsAt: Date?

    var remainingPercent: Double {
        min(max(100 - usedPercent, 0), 100)
    }
}

struct CodexDailyTokenUsage: Equatable, Sendable {
    let startDate: String
    let tokens: Int
}

struct CodexTokenActivity: Equatable, Sendable {
    let lifetimeTokens: Int?
    let peakDailyTokens: Int?
    let longestRunningTurnSeconds: Int?
    let currentStreakDays: Int?
    let longestStreakDays: Int?
    let dailyBuckets: [CodexDailyTokenUsage]

    static let empty = CodexTokenActivity(
        lifetimeTokens: nil,
        peakDailyTokens: nil,
        longestRunningTurnSeconds: nil,
        currentStreakDays: nil,
        longestStreakDays: nil,
        dailyBuckets: []
    )

    func tokens(on date: Date, calendar: Calendar = .current) -> Int {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return dailyBuckets.first(where: { $0.startDate == key })?.tokens ?? 0
    }

    func tokens(inLastDays days: Int, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard days > 0,
              let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now))
        else { return 0 }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let startKey = formatter.string(from: start)
        let endKey = formatter.string(from: now)
        return dailyBuckets
            .filter { $0.startDate >= startKey && $0.startDate <= endKey }
            .reduce(0) { $0 + $1.tokens }
    }
}

struct CodexAccountUsageSnapshot: Equatable, Sendable {
    let profileID: UUID
    let planType: String?
    let primaryWindow: CodexAccountRateWindow?
    let secondaryWindow: CodexAccountRateWindow?
    let tokenActivity: CodexTokenActivity
    let fetchedAt: Date

    var headroom: Double {
        let values = [primaryWindow?.remainingPercent, secondaryWindow?.remainingPercent].compactMap { $0 }
        return values.min() ?? 0
    }
}
