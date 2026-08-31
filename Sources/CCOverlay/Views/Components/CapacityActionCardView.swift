import SwiftUI

struct CapacityActionCardView: View {
    let decision: CapacityDecision

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("Next action", systemImage: iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(nextSafeLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }

            Text(decision.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(decision.detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                if let provider = decision.recommendedProvider {
                    Label(provider.rawValue, systemImage: provider.iconName)
                }
                Label("\(decision.confidence.label) confidence", systemImage: "checkmark.seal")
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)

            if let reason = decision.reasons.first {
                Label(reason, systemImage: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .compatGlassRoundedRect(cornerRadius: 12, interactive: false, tint: tint.opacity(0.07))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next action")
        .accessibilityValue(accessibilityValue)
    }

    private var nextSafeLabel: String {
        guard let nextSafeAt = decision.nextSafeAt else {
            return decision.kind == .waitForMac ? "Check after recovery" : "Check status"
        }
        if nextSafeAt.timeIntervalSinceNow <= 5 { return "Now" }
        return "Safe \(nextSafeAt.formatted(.relative(presentation: .named)))"
    }

    private var accessibilityValue: String {
        [decision.title, decision.detail, nextSafeLabel].joined(separator: ". ")
    }

    private var iconName: String {
        switch decision.kind {
        case .run: "play.fill"
        case .runWithCaution: "exclamationmark.triangle.fill"
        case .waitForMac, .waitForHeadroom: "pause.fill"
        case .switchProvider: "arrow.left.arrow.right"
        case .useReset: "arrow.counterclockwise.circle.fill"
        case .refresh: "arrow.clockwise"
        case .setup: "wrench.and.screwdriver"
        }
    }

    private var tint: Color {
        switch decision.kind {
        case .run: .mint
        case .switchProvider, .useReset: .brandAccent
        case .runWithCaution: .orange
        case .waitForMac, .waitForHeadroom: .red
        case .refresh, .setup: .secondary
        }
    }
}
