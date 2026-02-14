import SwiftUI

/// Displays Codex plan and credits information.
struct CreditsInfoCardView: View {
    let credits: CreditsDisplayInfo
    var size: Size = .standard

    enum Size {
        case compact
        case standard

        var headerFont: Font {
            switch self {
            case .compact: return .system(size: 10, weight: .semibold)
            case .standard: return .system(size: 11, weight: .medium)
            }
        }

        var padding: CGFloat {
            switch self {
            case .compact: return 10
            case .standard: return 14
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .compact: return 14
            case .standard: return 16
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            planBadge
            infoRows
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackgroundModifier(useGlass: size == .standard, cornerRadius: size.cornerRadius))
    }

    // MARK: - Header

    @ViewBuilder
    private var headerRow: some View {
        HStack {
            Text("Plan & Credits")
                .font(size.headerFont)
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "shield.checkered")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Plan Badge

    @ViewBuilder
    private var planBadge: some View {
        Text(credits.planType)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(planColor.opacity(0.8), in: Capsule())
    }

    private var planColor: Color {
        switch credits.planType.lowercased() {
        case "pro": return .purple
        case "max": return .orange
        case "plus": return .blue
        default: return .gray
        }
    }

    // MARK: - Info Rows

    @ViewBuilder
    private var infoRows: some View {
        VStack(spacing: 6) {
            infoRow(
                label: "Credits",
                value: creditsValue,
                valueColor: credits.unlimited ? .green : .primary
            )
            infoRow(
                label: "Extra Usage",
                value: credits.extraUsageEnabled ? "Enabled" : "Disabled",
                valueColor: credits.extraUsageEnabled ? .green : .secondary
            )
        }
    }

    private var creditsValue: String {
        if credits.unlimited { return "Unlimited" }
        if let balance = credits.balance, balance != "0" { return "$\(balance)" }
        if credits.hasCredits { return "Active" }
        return "—"
    }

    @ViewBuilder
    private func infoRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(valueColor)
        }
    }
}
