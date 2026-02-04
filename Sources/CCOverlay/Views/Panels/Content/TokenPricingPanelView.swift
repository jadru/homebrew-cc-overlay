import SwiftUI

struct TokenPricingPanelView: View {
    private let models: [ModelPricingInfo] = [
        ModelPricingInfo(
            name: "Claude Opus 4",
            prefix: "claude-opus-4",
            color: .purple,
            pricing: ModelPricing(inputPerMTok: 15, outputPerMTok: 75, cacheWritePerMTok: 18.75, cacheReadPerMTok: 1.50)
        ),
        ModelPricingInfo(
            name: "Claude Sonnet 4",
            prefix: "claude-sonnet-4",
            color: .blue,
            pricing: ModelPricing(inputPerMTok: 3, outputPerMTok: 15, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30)
        ),
        ModelPricingInfo(
            name: "Claude Haiku 3.5",
            prefix: "claude-3-5-haiku",
            color: .green,
            pricing: ModelPricing(inputPerMTok: 0.80, outputPerMTok: 4, cacheWritePerMTok: 1.0, cacheReadPerMTok: 0.08)
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(models) { model in
                    modelCard(model)
                }

                weightLegend
            }
            .padding(14)
        }
    }

    // MARK: - Model Card

    @ViewBuilder
    private func modelCard(_ model: ModelPricingInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(model.color).frame(width: 8, height: 8)
                Text(model.name)
                    .font(.system(size: 12, weight: .semibold))
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Type")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("$/MTok")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                priceRow("Input", model.pricing.inputPerMTok, .blue)
                priceRow("Output", model.pricing.outputPerMTok, .purple)
                priceRow("Cache Write", model.pricing.cacheWritePerMTok, .orange)
                priceRow("Cache Read", model.pricing.cacheReadPerMTok, .green)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    @ViewBuilder
    private func priceRow(_ label: String, _ price: Double, _ color: Color) -> some View {
        GridRow {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatPrice(price))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
    }

    // MARK: - Weight Legend

    @ViewBuilder
    private var weightLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cost Weights")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            HStack(spacing: 12) {
                weightChip("In", "1.0x")
                weightChip("Out", "5.0x")
                weightChip("CW", "1.25x")
                weightChip("CR", "0.1x")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    @ViewBuilder
    private func weightChip(_ label: String, _ weight: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(weight)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Formatting

    private func formatPrice(_ price: Double) -> String {
        if price < 1 {
            return String(format: "$%.2f", price)
        }
        return String(format: "$%.2f", price)
    }
}

// MARK: - Supporting Types

private struct ModelPricingInfo: Identifiable {
    let name: String
    let prefix: String
    let color: Color
    let pricing: ModelPricing

    var id: String { prefix }
}
