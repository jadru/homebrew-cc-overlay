import SwiftUI

struct UsageDecisionView: View {
    let decision: UsageDecision
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 7 : 10) {
            Image(systemName: symbolName)
                .font(.system(size: compact ? 10 : 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: compact ? 18 : 24, height: compact ? 18 : 24)
                .compatGlassCircle(tint: tint.opacity(0.11))

            VStack(alignment: .leading, spacing: 2) {
                Text(decision.title)
                    .font(.system(size: compact ? 10 : 12, weight: .semibold))
                    .foregroundStyle(.primary)

                if !compact {
                    Text(detailText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 2)

            Text(decision.kind == .run ? "RUN" : decision.kind == .switchProvider ? "SWITCH" : decision.kind == .wait ? "WAIT" : "SETUP")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, compact ? 5 : 8)
        .compatGlassRoundedRect(
            cornerRadius: compact ? 8 : 10,
            interactive: false,
            tint: tint.opacity(0.08)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Usage recommendation")
        .accessibilityValue("\(decision.title). \(detailText)")
    }

    private var detailText: String {
        guard decision.kind == .wait, let resetAt = decision.resetAt else {
            return decision.detail
        }
        let remaining = max(resetAt.timeIntervalSinceNow, 0)
        return "\(decision.detail) Next reset in \(DurationFormatting.compactReset(remaining))."
    }

    private var symbolName: String {
        switch decision.kind {
        case .run: return "play.fill"
        case .switchProvider: return "arrow.left.arrow.right"
        case .wait: return "clock.fill"
        case .setup: return "terminal"
        }
    }

    private var tint: Color {
        switch decision.kind {
        case .run: return .mint
        case .switchProvider: return .blue
        case .wait: return .orange
        case .setup: return .secondary
        }
    }
}
