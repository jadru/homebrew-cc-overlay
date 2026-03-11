import SwiftUI

struct ProviderSessionDetailsView: View {
    enum Size {
        case standard
        case compact

        var titleFont: Font {
            switch self {
            case .standard: return .system(size: 10, weight: .semibold)
            case .compact: return .system(size: 9, weight: .semibold)
            }
        }

        var valueFont: Font {
            switch self {
            case .standard: return .system(size: 11, weight: .medium, design: .monospaced)
            case .compact: return .system(size: 10, weight: .medium, design: .monospaced)
            }
        }

        var rowGap: CGFloat {
            switch self {
            case .standard: return 10
            case .compact: return 8
            }
        }

        var padding: CGFloat {
            switch self {
            case .standard: return 12
            case .compact: return 10
            }
        }
    }

    let data: ProviderUsageData
    var size: Size = .standard

    var body: some View {
        if data.isAvailable, data.resetsAt != nil || data.lastActivityAt != nil {
            VStack(spacing: size.rowGap) {
                if let resetsAt = data.resetsAt {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        infoRow(
                            title: data.provider == .claudeCode ? "Session resets" : "\(data.primaryWindowLabel) resets",
                            value: countdownText(until: resetsAt, now: context.date)
                        )
                    }
                }

                if let lastActivityAt = data.lastActivityAt {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        infoRow(
                            title: "Last active",
                            value: elapsedText(since: lastActivityAt, now: context.date)
                        )
                    }
                }
            }
            .padding(size.padding)
            .cardBackground(useGlass: size == .standard, cornerRadius: size == .standard ? 16 : 14)
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(size.titleFont)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(size.valueFont)
                .foregroundStyle(.primary)
                .contentTransition(.numericText(countsDown: true))
        }
    }

    private func countdownText(until date: Date, now: Date) -> String {
        let interval = max(0, date.timeIntervalSince(now))
        if interval < 60 {
            return "now"
        }

        let totalMinutes = Int(interval) / 60
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", minutes))m"
        }
        return "\(minutes)m"
    }

    private func elapsedText(since date: Date, now: Date) -> String {
        let interval = max(0, now.timeIntervalSince(date))
        if interval < 60 {
            return "just now"
        }

        let totalMinutes = Int(interval) / 60
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "\(days)d ago"
        }
        if hours > 0 {
            return "\(hours)h ago"
        }
        return "\(minutes)m ago"
    }
}
