import Foundation

enum DateParsing {
    private final class FormatterCache: @unchecked Sendable {
        private let fractionalFormatter: ISO8601DateFormatter
        private let standardFormatter: ISO8601DateFormatter
        private let lock = NSLock()

        init() {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.fractionalFormatter = fractional

            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            self.standardFormatter = standard
        }

        func parseISO8601(_ string: String) -> Date? {
            lock.lock()
            defer { lock.unlock() }
            return fractionalFormatter.date(from: string) ?? standardFormatter.date(from: string)
        }
    }

    private static let cache = FormatterCache()

    static func parseISO8601(_ string: String) -> Date? {
        cache.parseISO8601(string)
    }
}
