import SwiftUI

/// A scan-friendly view of the primary rate-limit windows for the menu bar panel.
struct UsageTimelineView: View {
    let data: ProviderUsageData

    private var timelineBuckets: [RateBucket] {
        let labels = Self.primaryWindowLabels(from: data.rateLimitBuckets)
        let buckets = labels.compactMap { label in
            data.rateLimitBuckets.first { Self.canonicalWindowLabel($0.label) == label }
        }

        if !buckets.isEmpty {
            return buckets
        }

        return [
            RateBucket(
                label: data.primaryWindowLabel,
                utilization: data.usedPercentage,
                resetsAt: data.resetsAt
            ),
        ]
    }

    private var additionalBuckets: [RateBucket] {
        Self.visibleAdditionalBuckets(from: data.rateLimitBuckets)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 0) {
                summary(now: context.date)

                Divider()
                    .overlay(Color.dividerSubtle)
                    .padding(.vertical, 14)

                ForEach(Array(timelineBuckets.enumerated()), id: \.element.id) { index, bucket in
                    timelineRow(bucket, now: context.date)

                    if index < timelineBuckets.count - 1 {
                        Divider()
                            .overlay(Color.dividerSubtle)
                            .padding(.vertical, 14)
                    }
                }

                if !additionalBuckets.isEmpty {
                    Divider()
                        .overlay(Color.dividerSubtle)
                        .padding(.vertical, 12)

                    additionalLimits
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Usage timeline")
    }

    @ViewBuilder
    private func summary(now: Date) -> some View {
        let primary = timelineBuckets.first
        let pace = primary.map {
            RateWindowPace.assess(
                label: $0.label,
                utilization: $0.utilization,
                resetsAt: $0.resetsAt,
                now: now
            )
        }

        HStack(alignment: .center, spacing: 12) {
            Text(NumberFormatting.formatPercentage(data.remainingPercentage))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            VStack(alignment: .leading, spacing: 3) {
                Text(data.isEstimated ? "local estimate" : "left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                if let resetsAt = data.resetsAt, resetsAt > now {
                    Label("Resets in \(countdownText(until: resetsAt, now: now))", systemImage: "clock")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                } else {
                    Text(data.primaryWindowLabel.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 12)

            if let pace {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(paceTitle(for: pace))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(paceColor(for: pace))

                    Text(primary.map { displayLabel(for: $0.label) } ?? "Usage")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(minHeight: 62)
    }

    @ViewBuilder
    private func timelineRow(_ bucket: RateBucket, now: Date) -> some View {
        let pace = RateWindowPace.assess(
            label: bucket.label,
            utilization: bucket.utilization,
            resetsAt: bucket.resetsAt,
            now: now
        )
        let tint = Color.chartTint(for: pace.utilization)
        let remaining = max(0, min(100, 100 - pace.utilization))

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(displayLabel(for: bucket.label))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(windowDescription(for: bucket.label))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text(paceTitle(for: pace))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(paceColor(for: pace))
            }

            GeometryReader { proxy in
                let usedWidth = proxy.size.width * CGFloat(pace.utilization / 100)
                let expectedOffset = proxy.size.width * CGFloat(pace.expectedUtilization / 100)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(tint)
                        .frame(width: max(usedWidth, pace.utilization > 0 ? 2 : 0))

                    if pace.status != .unavailable {
                        Rectangle()
                            .fill(Color.primary.opacity(0.55))
                            .frame(width: 1, height: 12)
                            .offset(x: min(max(expectedOffset, 0), max(proxy.size.width - 1, 0)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            .frame(height: 7)

            HStack {
                Text("\(Int(pace.utilization.rounded()))% used")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(tint)

                Spacer()

                if let resetsAt = bucket.resetsAt, resetsAt > now {
                    Text("\(Int(remaining.rounded()))% left · resets in \(countdownText(until: resetsAt, now: now))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(Int(remaining.rounded()))% left")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayLabel(for: bucket.label)) window")
        .accessibilityValue("\(Int(remaining.rounded())) percent remaining, \(paceTitle(for: pace))")
    }

    private var additionalLimits: some View {
        HStack(spacing: 8) {
            Text("Other limits")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(additionalBuckets) { bucket in
                Text("\(bucket.label) \(Int((100 - bucket.utilization).rounded()))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.chartTint(for: bucket.utilization))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    nonisolated static func primaryWindowLabels(from buckets: [RateBucket]) -> [String] {
        ["5h", "7d"].filter { expected in
            buckets.contains { canonicalWindowLabel($0.label) == expected }
        }
    }

    nonisolated static func visibleAdditionalBuckets(from buckets: [RateBucket]) -> [RateBucket] {
        buckets.filter { bucket in
            canonicalWindowLabel(bucket.label) == nil
                && bucket.label.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare("Spark") != .orderedSame
        }
    }

    nonisolated private static func canonicalWindowLabel(_ label: String) -> String? {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "5h": return "5h"
        case "1w", "7d": return "7d"
        default: return nil
        }
    }

    private func displayLabel(for label: String) -> String {
        switch Self.canonicalWindowLabel(label) {
        case "5h": return "5H"
        case "7d": return "7D"
        default: return label
        }
    }

    private func windowDescription(for label: String) -> String {
        switch Self.canonicalWindowLabel(label) {
        case "5h": return "short window"
        case "7d": return "weekly window"
        default: return "limit"
        }
    }

    private func paceTitle(for pace: RateWindowPace) -> String {
        switch pace.status {
        case .burningFast: return "Fast burn"
        case .onPace: return "On pace"
        case .plentyLeft: return "Plenty left"
        case .unavailable: return "Current usage"
        }
    }

    private func paceColor(for pace: RateWindowPace) -> Color {
        switch pace.status {
        case .burningFast: return .orange
        case .onPace: return .secondary
        case .plentyLeft: return .mint
        case .unavailable: return .secondary
        }
    }

    private func countdownText(until date: Date, now: Date) -> String {
        let totalMinutes = max(0, Int(date.timeIntervalSince(now)) / 60)
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
}
