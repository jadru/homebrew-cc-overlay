import SwiftUI

/// A card displaying estimated costs for 5-hour window and daily totals with breakdown chips.
struct CostCardView: View {
    let fiveHourCost: CostBreakdown
    let dailyCost: CostBreakdown
    var size: Size = .standard

    enum Size {
        case compact  // For ClaudeUsagePanelView
        case standard // For MenuBarView

        var headerFont: Font {
            switch self {
            case .compact: return .system(size: 10, weight: .semibold)
            case .standard: return .system(size: 11, weight: .medium)
            }
        }

        var valueFont: Font {
            switch self {
            case .compact: return .system(size: 15, weight: .semibold, design: .rounded)
            case .standard: return .system(size: 18, weight: .semibold, design: .rounded)
            }
        }

        var labelFont: Font {
            switch self {
            case .compact: return .system(size: 8, weight: .medium)
            case .standard: return .system(size: 10)
            }
        }

        var dividerHeight: CGFloat {
            switch self {
            case .compact: return 26
            case .standard: return 32
            }
        }

        var spacing: CGFloat {
            switch self {
            case .compact: return 8
            case .standard: return 8
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
        VStack(spacing: size.spacing) {
            headerRow
            costColumns
            if fiveHourCost.totalCost > 0 {
                CostBreakdownChips(
                    inputCost: fiveHourCost.inputCost,
                    outputCost: fiveHourCost.outputCost,
                    cacheWriteCost: fiveHourCost.cacheWriteCost,
                    cacheReadCost: fiveHourCost.cacheReadCost,
                    size: size == .compact ? .compact : .regular
                )
                .padding(.top, size == .compact ? 2 : 0)
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity)
        .modifier(CardBackgroundModifier(useGlass: size == .standard, cornerRadius: size.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estimated cost: \(NumberFormatting.formatDollarCost(fiveHourCost.totalCost)) for 5 hour window, \(NumberFormatting.formatDollarCost(dailyCost.totalCost)) today")
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack {
            Text("Estimated Cost")
                .font(size.headerFont)
                .foregroundStyle(size == .compact ? .tertiary : .secondary)
                .textCase(size == .compact ? .uppercase : .none)
                .tracking(size == .compact ? 0.3 : 0)
            Spacer()
            if size == .standard {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var costColumns: some View {
        HStack(spacing: 0) {
            costColumn(
                value: NumberFormatting.formatDollarCost(fiveHourCost.totalCost),
                label: "5h window"
            )

            Rectangle()
                .fill(Color.secondary.opacity(size == .compact ? 0.1 : 0.15))
                .frame(width: size == .compact ? 0.5 : 1, height: size.dividerHeight)

            costColumn(
                value: NumberFormatting.formatDollarCost(dailyCost.totalCost),
                label: "today"
            )
        }
    }

    @ViewBuilder
    private func costColumn(value: String, label: String) -> some View {
        VStack(spacing: size == .compact ? 2 : 3) {
            Text(value)
                .font(size.valueFont)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text(label)
                .font(size.labelFont)
                .foregroundStyle(size == .compact ? .quaternary : .tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Standard") {
    CostCardView(
        fiveHourCost: CostBreakdown(
            inputCost: 0.15,
            outputCost: 0.42,
            cacheWriteCost: 0.08,
            cacheReadCost: 0.02
        ),
        dailyCost: CostBreakdown(
            inputCost: 0.45,
            outputCost: 1.20,
            cacheWriteCost: 0.15,
            cacheReadCost: 0.05
        ),
        size: .standard
    )
    .frame(width: 280)
    .padding()
}

#Preview("Compact") {
    CostCardView(
        fiveHourCost: CostBreakdown(
            inputCost: 0.15,
            outputCost: 0.42,
            cacheWriteCost: 0.08,
            cacheReadCost: 0.02
        ),
        dailyCost: CostBreakdown(
            inputCost: 0.45,
            outputCost: 1.20,
            cacheWriteCost: 0.15,
            cacheReadCost: 0.05
        ),
        size: .compact
    )
    .frame(width: 260)
    .padding()
}
