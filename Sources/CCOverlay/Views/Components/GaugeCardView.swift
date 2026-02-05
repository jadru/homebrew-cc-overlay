import SwiftUI

/// A circular gauge card showing remaining usage percentage with optional reset countdown and weekly warning.
struct GaugeCardView: View {
    let remainingPercentage: Double
    var resetsAt: Date?
    var weeklyWarningPercentage: Int?
    var showLiveIndicator: Bool = false
    var rateLimitBuckets: [RateLimitBucket] = []
    var size: Size = .standard
    var title: String = "Session Limit"

    struct RateLimitBucket {
        let label: String
        let percentage: Int
        var showWarning: Bool = false
        var dimmed: Bool = false
    }

    enum Size {
        case compact   // For ClaudeUsagePanelView (68x68)
        case standard  // For MenuBarView (88x88)

        var gaugeSize: CGFloat {
            switch self {
            case .compact: return 68
            case .standard: return 88
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .compact: return 5
            case .standard: return 8
            }
        }

        var percentageFont: Font {
            switch self {
            case .compact: return .system(size: 18, weight: .bold, design: .rounded)
            case .standard: return .system(size: 24, weight: .bold, design: .rounded)
            }
        }

        var subtitleFont: Font {
            switch self {
            case .compact: return .system(size: 8, weight: .medium)
            case .standard: return .system(size: 10)
            }
        }

        var titleFont: Font {
            switch self {
            case .compact: return .system(size: 9, weight: .semibold)
            case .standard: return .system(size: 11, weight: .medium)
            }
        }
    }

    private var tintColor: Color {
        Color.usageTint(for: remainingPercentage)
    }

    var body: some View {
        VStack(spacing: size == .compact ? 6 : 10) {
            titleSection
            gaugeCircle
            if !rateLimitBuckets.isEmpty {
                rateLimitPills
            }
            if resetsAt != nil || showLiveIndicator {
                footerSection
            }
        }
        .padding(.vertical, size == .compact ? 12 : 14)
        .padding(.horizontal, size == .compact ? 10 : 14)
        .frame(maxWidth: .infinity)
        .modifier(CardBackgroundModifier(useGlass: size == .standard, cornerRadius: size == .compact ? 14 : 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usage gauge")
        .accessibilityValue("\(Int(remainingPercentage)) percent remaining")
        .accessibilityHint("Shows your Claude session limit status")
    }

    // MARK: - Title Section

    @ViewBuilder
    private var titleSection: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(size.titleFont)
                .foregroundStyle(.secondary)
                .textCase(size == .compact ? .uppercase : .none)
                .tracking(size == .compact ? 0.5 : 0)

            if let weeklyPct = weeklyWarningPercentage {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                    Text("Weekly at \(weeklyPct)%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Gauge Circle

    @ViewBuilder
    private var gaugeCircle: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(size == .compact ? 0.08 : 0.12), lineWidth: size.lineWidth)

            Circle()
                .trim(from: 0, to: remainingPercentage / 100)
                .stroke(tintColor, style: StrokeStyle(lineWidth: size.lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: remainingPercentage)

            VStack(spacing: size == .compact ? 1 : 2) {
                Text(NumberFormatting.formatPercentage(remainingPercentage))
                    .font(size.percentageFont)
                    .foregroundStyle(size == .compact ? tintColor : .primary)
                    .contentTransition(.numericText())

                Text("remaining")
                    .font(size.subtitleFont)
                    .foregroundStyle(size == .compact ? .quaternary : .tertiary)
            }
        }
        .frame(width: size.gaugeSize, height: size.gaugeSize)
    }

    // MARK: - Rate Limit Pills

    @ViewBuilder
    private var rateLimitPills: some View {
        HStack(spacing: 8) {
            ForEach(rateLimitBuckets, id: \.label) { bucket in
                RatePillView(
                    label: bucket.label,
                    percentage: bucket.percentage,
                    showWarningIcon: bucket.showWarning,
                    size: size == .compact ? .regular : .large
                )
                .opacity(bucket.dimmed ? 0.5 : 1.0)
            }
        }
    }

    // MARK: - Footer Section

    @ViewBuilder
    private var footerSection: some View {
        HStack(spacing: 8) {
            if let resetsAt, resetsAt > Date() {
                Label {
                    Text("Resets \(resetsAt, style: .relative)")
                        .font(.system(size: size == .compact ? 9 : 10))
                } icon: {
                    Image(systemName: "clock")
                        .font(.system(size: size == .compact ? 8 : 9))
                }
                .foregroundStyle(size == .compact ? .quaternary : .tertiary)
            }

            if showLiveIndicator {
                Spacer()
                HStack(spacing: 3) {
                    Circle().fill(.green).frame(width: 4, height: 4)
                    Text("Live").font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview("Standard Size") {
    GaugeCardView(
        remainingPercentage: 65,
        resetsAt: Date().addingTimeInterval(3600 * 2),
        weeklyWarningPercentage: 75,
        showLiveIndicator: true,
        rateLimitBuckets: [
            .init(label: "5h", percentage: 35),
            .init(label: "7d", percentage: 75, showWarning: true),
            .init(label: "Sonnet", percentage: 45, dimmed: true)
        ],
        size: .standard
    )
    .frame(width: 280)
    .padding()
}

#Preview("Compact Size") {
    GaugeCardView(
        remainingPercentage: 25,
        resetsAt: Date().addingTimeInterval(3600),
        size: .compact,
        title: "Session Limit"
    )
    .frame(width: 260)
    .padding()
}
