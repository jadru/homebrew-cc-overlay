import SwiftUI

/// Compact rate-window meter for the expanded overlay.
struct OverlayRateWindowPaceView: View {
    let label: String
    let utilization: Double
    let resetsAt: Date?

    private var pace: RateWindowPace {
        RateWindowPace.assess(
            label: label,
            utilization: utilization,
            resetsAt: resetsAt
        )
    }

    private var remainingPercentage: Int {
        Int((100 - pace.utilization).rounded())
    }

    private var tint: Color {
        Color.chartTint(for: pace.utilization)
    }

    private var statusTitle: String {
        switch pace.status {
        case .burningFast: return "Fast burn"
        case .onPace: return "On pace"
        case .plentyLeft: return "Plenty left"
        case .unavailable: return "Current usage"
        }
    }

    private var statusColor: Color {
        switch pace.status {
        case .burningFast: return .orange
        case .onPace: return .secondary
        case .plentyLeft: return .mint
        case .unavailable: return Color.secondary.opacity(0.65)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Text("\(remainingPercentage)% left")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }

            paceMeter

            HStack(spacing: 3) {
                Image(systemName: statusSymbol)
                    .font(.system(size: 7, weight: .semibold))
                Text(statusTitle)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(statusColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) window")
        .accessibilityValue("\(remainingPercentage) percent remaining, \(statusTitle)")
    }

    private var paceMeter: some View {
        GeometryReader { proxy in
            let usedWidth = proxy.size.width * CGFloat(pace.utilization / 100)
            let expectedOffset = proxy.size.width * CGFloat(pace.expectedUtilization / 100)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))

                Capsule()
                    .fill(tint)
                    .frame(width: max(usedWidth, pace.utilization > 0 ? 2 : 0))

                if pace.status != .unavailable {
                    Rectangle()
                        .fill(Color.primary.opacity(0.42))
                        .frame(width: 1, height: 8)
                        .offset(x: min(max(expectedOffset, 0), max(proxy.size.width - 1, 0)))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }

    private var statusSymbol: String {
        switch pace.status {
        case .burningFast: return "flame.fill"
        case .onPace: return "equal"
        case .plentyLeft: return "checkmark"
        case .unavailable: return "chart.bar"
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        OverlayRateWindowPaceView(
            label: "5h",
            utilization: 74,
            resetsAt: Date().addingTimeInterval(2 * 60 * 60)
        )
        OverlayRateWindowPaceView(
            label: "7d",
            utilization: 18,
            resetsAt: Date().addingTimeInterval(5 * AppConstants.secondsPerDay)
        )
    }
    .frame(width: 260)
    .padding()
}
