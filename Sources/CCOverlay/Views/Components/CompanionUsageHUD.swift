import SwiftUI

/// Persistent compact readout for the most constrained live usage window.
/// Reset information deliberately stays on hover so the companion remains a
/// small overlay rather than turning into a floating dashboard.
struct CompanionUsageHUD: View {
    let presentation: PatchPresentation
    let treats: Int
    let feedCost: Int
    let canFeed: Bool
    var maximumWidth: CGFloat = 144
    let feedOneServing: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: isHovering && presentation.resetAt != nil ? 4 : 0) {
            primaryRow

            if isHovering, let resetAt = presentation.resetAt {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 8, weight: .bold))
                    Text(DurationFormatting.compactReset(resetAt.timeIntervalSinceNow))
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: maximumWidth - 14, alignment: .center)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(width: maximumWidth)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.28), radius: 2, y: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.2), value: isHovering)
        .onHover { isHovering = $0 }
        .help(hoverHelp)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Live usage: \(remainingText). \(hoverHelp). \(treats) companion treats.")
    }

    private var remainingText: String {
        guard let headroom = presentation.headroomPercentage else { return "Usage --" }
        return "\(Int(headroom.rounded()))% left"
    }

    private var tint: Color {
        guard let headroom = presentation.headroomPercentage else { return .secondary }
        return Color.usageTint(for: headroom)
    }

    private var hoverHelp: String {
        guard let resetAt = presentation.resetAt else { return "Next reset is not reported." }
        return "Resets in \(DurationFormatting.compactReset(resetAt.timeIntervalSinceNow))"
    }

    private var primaryRow: some View {
        ViewThatFits(in: .horizontal) {
            standardPrimaryRow
            compactPrimaryRow
        }
        .frame(maxWidth: .infinity)
    }

    private var standardPrimaryRow: some View {
        HStack(spacing: 5) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)

            Text(compactHeadroomText)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .contentTransition(.numericText())

            Capsule()
                .fill(tint.opacity(0.27))
                .frame(width: 24, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .frame(width: 24 * max(0, min((presentation.headroomPercentage ?? 0) / 100, 1)), height: 4)
                }

            Rectangle()
                .fill(Color.primary.opacity(0.13))
                .frame(width: 1, height: 11)

            TreatFeedControl(
                treats: treats,
                feedCost: feedCost,
                canFeed: canFeed,
                feedOneServing: feedOneServing
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var compactPrimaryRow: some View {
        HStack(spacing: 4) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(tint)

            Text(compactHeadroomText)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .monospacedDigit()

            Capsule()
                .fill(tint.opacity(0.27))
                .frame(width: 20, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .frame(width: 20 * max(0, min((presentation.headroomPercentage ?? 0) / 100, 1)), height: 4)
                }

            Rectangle()
                .fill(Color.primary.opacity(0.13))
                .frame(width: 1, height: 10)

            TreatFeedControl(
                treats: treats,
                feedCost: feedCost,
                canFeed: canFeed,
                compact: true,
                feedOneServing: feedOneServing
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var compactHeadroomText: String {
        guard let headroom = presentation.headroomPercentage else { return "--" }
        return "\(Int(headroom.rounded()))%"
    }
}

private struct TreatFeedControl: View {
    let treats: Int
    let feedCost: Int
    let canFeed: Bool
    var compact = false
    let feedOneServing: () -> Void

    var body: some View {
        Group {
            if canFeed, treats >= feedCost {
                Button(action: feedOneServing) {
                    treatCount
                        .padding(.horizontal, compact ? 3 : 5)
                        .padding(.vertical, compact ? 2 : 3)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Feed one care serving for \(feedCost) treats")
                .accessibilityLabel("Feed one care serving for \(feedCost) treats. \(treats) treats available")
            } else {
                treatCount
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var treatCount: some View {
        HStack(spacing: 3) {
            Image(systemName: "carrot.fill")
            Text(compactTreatCount)
                .monospacedDigit()
            Text("−\(feedCost)")
                .font(.system(size: compact ? 6 : 7, weight: .bold, design: .rounded))
                .padding(.horizontal, compact ? 2 : 3)
                .padding(.vertical, 1)
                .background(Color.orange.opacity(0.20), in: Capsule())
        }
        .font(.system(size: compact ? 9 : 10, weight: .bold, design: .rounded))
        .foregroundStyle(.orange)
    }

    private var compactTreatCount: String {
        guard treats >= 1_000 else { return "\(treats)" }
        return "\(treats / 1_000)k"
    }
}
