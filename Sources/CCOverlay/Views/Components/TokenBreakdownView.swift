import SwiftUI

struct TokenBreakdownView: View {
    let usage: TokenUsage
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                tokenRow(label: "Input", count: usage.inputTokens, weight: "1.0x", color: .blue)
                tokenRow(label: "Output", count: usage.outputTokens, weight: "5.0x", color: .purple)
                if usage.cacheCreationInputTokens > 0 {
                    tokenRow(label: "Cache Write", count: usage.cacheCreationInputTokens, weight: "1.25x", color: .orange)
                }
                if usage.cacheReadInputTokens > 0 {
                    tokenRow(label: "Cache Read", count: usage.cacheReadInputTokens, weight: "0.1x", color: .green)
                }

                Divider()
                    .gridCellColumns(4)

                GridRow {
                    Text("Raw")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text("")
                    Text(NumberFormatting.formatTokenCount(usage.totalTokens))
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .contentTransition(.numericText())
                }

                GridRow {
                    Text("Weighted")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("")
                    Text(NumberFormatting.formatWeightedCost(usage.weightedCost))
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(NumberFormatting.formatTokenCount(usage.totalTokens)) total tokens, \(NumberFormatting.formatWeightedCost(usage.weightedCost)) weighted cost")
    }

    @ViewBuilder
    private func tokenRow(label: String, count: Int, weight: String, color: Color) -> some View {
        GridRow {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(weight)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)

            Text(NumberFormatting.formatTokenCount(count))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: count)
        }
    }
}
