import SwiftUI

/// Displays per-project cost breakdown in a list card.
struct ProjectCostCardView: View {
    let projects: [ProjectCostSummary]
    var size: ComponentSize = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardHeader(
                title: "Projects",
                iconName: "folder",
                size: size
            )

            ForEach(projects) { project in
                projectRow(project)
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackgroundModifier(useGlass: size == .standard, cornerRadius: size.cornerRadius))
    }

    @ViewBuilder
    private func projectRow(_ project: ProjectCostSummary) -> some View {
        HStack {
            Text(project.projectName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(NumberFormatting.formatDollarCost(project.cost.totalCost))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            Text("\(project.sessionCount)s")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }
}
