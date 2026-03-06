import SwiftUI

/// Displays per-project cost breakdown in a list card.
struct ProjectCostCardView: View {
    let projects: [ProjectCostSummary]
    var maxVisibleRows: Int? = nil
    var size: ComponentSize = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardHeader(
                title: "Projects",
                iconName: "folder",
                size: size
            )

            let visibleRows = displayedProjects
            ForEach(Array(visibleRows)) { project in
                projectRow(project)
            }

            if let maxVisibleRows, projects.count > maxVisibleRows {
                Text("+ \(projects.count - maxVisibleRows) more")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackgroundModifier(useGlass: size == .standard, cornerRadius: size.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Project cost breakdown")
    }

    private var displayedProjects: [ProjectCostSummary] {
        guard let maxVisibleRows else { return projects }
        if projects.count > maxVisibleRows {
            return Array(projects.prefix(maxVisibleRows))
        }
        return Array(projects.prefix(maxVisibleRows))
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

            Text("\(project.sessionCount) sessions")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(project.projectName), \(NumberFormatting.formatDollarCost(project.cost.totalCost)), \(project.sessionCount) sessions"
        )
    }
}
