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

    /// `ps` reports process CPU as a percentage of one logical core, so a
    /// process using multiple cores may legitimately exceed 100 percent.
    static func formatCoreUsage(_ percentage: Double) -> String {
        String(format: "%.1f cores", percentage / 100)
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

    static func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .memory)
    }

    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func formatRate(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond else { return "—" }
        return "\(formatBytes(UInt64(max(bytesPerSecond, 0))))/s"
    }

    /// A no-whitespace transfer rate for the constrained floating overlay.
    /// Keeping the unit attached prevents the value from wrapping onto a second
    /// line in the horizontal and two-column layouts.
    static func formatOverlayRate(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond else { return "—" }

        let value = max(bytesPerSecond, 0)
        let units: [(threshold: Double, suffix: String)] = [
            (1_000_000_000, "GB/s"),
            (1_000_000, "MB/s"),
            (1_000, "KB/s"),
        ]
        for unit in units where value >= unit.threshold {
            let scaled = value / unit.threshold
            let precision = scaled < 10 ? "%.1f" : "%.0f"
            return "\(String(format: precision, scaled))\(unit.suffix)"
        }
        return "\(Int(value.rounded()))B/s"
    }
}
