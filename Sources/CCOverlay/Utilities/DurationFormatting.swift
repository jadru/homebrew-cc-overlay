import Foundation

enum DurationFormatting {
    nonisolated static func compactReset(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval) / 60)

        if totalMinutes >= 24 * 60 {
            let days = totalMinutes / (24 * 60)
            let hours = (totalMinutes % (24 * 60)) / 60
            return "\(days)d \(hours)h"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(String(format: "%02d", minutes))m"
    }
}
