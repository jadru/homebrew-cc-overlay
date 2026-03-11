import SwiftUI

/// A card displaying estimated costs for 5-hour window and daily totals with breakdown chips.
struct CostCardView: View {
    let fiveHourCost: CostBreakdown
    let dailyCost: CostBreakdown
    var size: ComponentSize = .standard
    var windowLabel: String = "5h window"
    var dailyLabel: String = "today"

    private var valueFont: Font {
        size == .compact ? .system(size: 15, weight: .semibold, design: .rounded)
                         : .system(size: 18, weight: .semibold, design: .rounded)
    }

    private var labelFont: Font {
        size == .compact ? .system(size: 8, weight: .medium) : .system(size: 10)
    }

    private var dividerHeight: CGFloat { size == .compact ? 26 : 32 }

    private var costSpacing: CGFloat { 8 }

    var body: some View {
        VStack(spacing: costSpacing) {
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
        CardHeader(
            title: "Estimated Cost",
            iconName: "dollarsign.circle",
            size: size
        )
    }

    @ViewBuilder
    private var costColumns: some View {
        HStack(spacing: 0) {
            costColumn(
                value: NumberFormatting.formatDollarCost(fiveHourCost.totalCost),
                label: windowLabel,
                amount: fiveHourCost.totalCost
            )

            Capsule()
                .fill(Color.dividerSubtle)
                .frame(width: size == .compact ? 4 : 6, height: dividerHeight)

            costColumn(
                value: NumberFormatting.formatDollarCost(dailyCost.totalCost),
                label: dailyLabel,
                amount: dailyCost.totalCost
            )
        }
    }

    @ViewBuilder
    private func costColumn(value: String, label: String, amount: Double) -> some View {
        VStack(spacing: size == .compact ? 2 : 3) {
            Text(value)
                .font(valueFont)
                .foregroundStyle(amount > 0 ? Color.brandAccent : .primary)
                .contentTransition(.numericText())
            Text(label)
                .font(labelFont)
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
