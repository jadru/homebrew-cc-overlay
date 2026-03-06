import SwiftUI

/// Displays per-model token and cost breakdown for the current provider usage period.
struct ModelBreakdownCardView: View {
    let models: [ModelUsageSummary]
    var maxVisibleRows: Int? = nil
    var size: ComponentSize = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardHeader(
                title: "Model Usage",
                iconName: "cpu.fill",
                size: size
            )

            ForEach(displayedModels) { model in
                modelRow(model)
            }

            if let maxVisibleRows, models.count > maxVisibleRows {
                Text("+ \(models.count - maxVisibleRows) more")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackgroundModifier(useGlass: size == .standard, cornerRadius: size.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Model usage breakdown")
    }

    private var displayedModels: [ModelUsageSummary] {
        guard let maxVisibleRows else { return models }
        if models.count > maxVisibleRows {
            return Array(models.prefix(maxVisibleRows))
        }
        return Array(models.prefix(maxVisibleRows))
    }

    @ViewBuilder
    private func modelRow(_ model: ModelUsageSummary) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(model.model)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text(NumberFormatting.formatDollarCost(model.cost.totalCost))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(NumberFormatting.formatTokenCount(model.tokenUsage.totalTokens))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("\(model.messageCount) messages")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(model.model), \(NumberFormatting.formatDollarCost(model.cost.totalCost)), \(model.tokenUsage.totalTokens) tokens, \(model.messageCount) messages"
        )
    }
}
