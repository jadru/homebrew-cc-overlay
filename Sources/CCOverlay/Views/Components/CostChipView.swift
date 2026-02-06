import SwiftUI

/// A small chip displaying a cost label with a colored indicator dot.
struct CostChipView: View {
    let label: String
    let amount: Double
    let color: Color
    var size: Size = .regular

    enum Size {
        case compact  // For ClaudeUsagePanelView (8pt font)
        case regular  // For MenuBarView (9pt font)

        var dotSize: CGFloat {
            switch self {
            case .compact: return 4
            case .regular: return 5
            }
        }

        var font: Font {
            switch self {
            case .compact: return .system(size: 8, weight: .medium, design: .monospaced)
            case .regular: return .system(size: 9, weight: .medium, design: .monospaced)
            }
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: size.dotSize, height: size.dotSize)
            Text("\(label) \(NumberFormatting.formatDollarCost(amount))")
                .font(size.font)
                .foregroundStyle(size == .compact ? .quaternary : .tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) cost: \(NumberFormatting.formatDollarCost(amount))")
    }
}

/// A horizontal stack of cost chips for input and output token types.
struct CostBreakdownChips: View {
    let inputCost: Double
    let outputCost: Double
    let cacheWriteCost: Double
    let cacheReadCost: Double
    var size: CostChipView.Size = .regular

    var body: some View {
        HStack(spacing: size == .compact ? 8 : 12) {
            CostChipView(label: "In", amount: inputCost, color: .blue, size: size)
            CostChipView(label: "Out", amount: outputCost, color: .purple, size: size)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CostBreakdownChips(
            inputCost: 0.15,
            outputCost: 0.42,
            cacheWriteCost: 0.08,
            cacheReadCost: 0.02,
            size: .regular
        )
        CostBreakdownChips(
            inputCost: 0.15,
            outputCost: 0.42,
            cacheWriteCost: 0.08,
            cacheReadCost: 0.02,
            size: .compact
        )
    }
    .padding()
}
