import Foundation

enum NumberFormatting {
    /// Format a token count into a human-readable string.
    /// Examples: 1234 → "1.2K", 1_500_000 → "1.5M", 500 → "500"
    static func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000_000 {
            return String(format: "%.1fB", Double(count) / 1_000_000_000)
        } else if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    /// Format a percentage value. Example: 72.3456 → "72%"
    static func formatPercentage(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    /// Format weighted cost units (Double). Same display logic as token count.
    static func formatWeightedCost(_ cost: Double) -> String {
        formatTokenCount(Int(cost.rounded()))
    }

    /// Format a dollar amount. Examples: 0.42 → "$0.42", 3.7 → "$3.70", 0.001 → "<$0.01"
    static func formatDollarCost(_ amount: Double) -> String {
        if amount < 0.01 && amount > 0 {
            return "<$0.01"
        }
        return String(format: "$%.2f", amount)
    }

    /// Compact dollar format for overlay. Examples: 0.42 → "42¢", 3.70 → "$3.70"
    static func formatDollarCompact(_ amount: Double) -> String {
        if amount < 0.01 && amount > 0 {
            return "<1¢"
        }
        if amount < 1.0 {
            return String(format: "%.0f¢", amount * 100)
        }
        return String(format: "$%.2f", amount)
    }
}
