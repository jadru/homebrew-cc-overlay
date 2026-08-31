import SwiftUI

/// Recent local project activity. The data source labels make the distinction
/// between Claude's API-equivalent estimate and Codex's token-only data clear.
struct ProjectUsageCardView: View {
    let projects: [ProjectUsageSummary]
    var notice: String? = nil
    var size: ComponentSize = .standard

    @State private var showsAllProjects = false

    private var visibleProjects: [ProjectUsageSummary] {
        showsAllProjects ? projects : Array(projects.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardHeader(
                title: "Project activity (24h)",
                iconName: "folder",
                size: size
            )

            if projects.isEmpty {
                Text("No local project activity in the last 24 hours.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleProjects) { project in
                    projectRow(project)
                }

                if projects.count > 3 {
                    Button(showsAllProjects ? "Show top 3" : "Show all \(projects.count) projects") {
                        showsAllProjects.toggle()
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.brandAccent)
                    .accessibilityLabel(showsAllProjects ? "Show top 3 projects" : "Show all \(projects.count) projects")
                }
            }

            if let notice {
                Label(notice, systemImage: "info.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackgroundModifier(useGlass: size == .standard, cornerRadius: size.cornerRadius))
    }

    @ViewBuilder
    private func projectRow(_ project: ProjectUsageSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(project.projectName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 4)

                Text(NumberFormatting.formatTokenCount(project.tokenUsage.totalTokens))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(NumberFormatting.formatTokenCount(project.tokenUsage.totalTokens)) tokens")
            }

            HStack(spacing: 5) {
                ForEach(project.providers) { provider in
                    Text(provider.shortLabel)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                        .accessibilityLabel(provider.rawValue)
                }

                Text("\(project.sessionCount) \(project.sessionCount == 1 ? "session" : "sessions")")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Spacer()

                if let estimate = project.claudeEstimatedCost {
                    Text("\(NumberFormatting.formatDollarCost(estimate.totalCost)) Claude est.")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(project.sources.map(\.label).joined(separator: " · "))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.projectName), \(project.sessionCount) sessions, \(NumberFormatting.formatTokenCount(project.tokenUsage.totalTokens)) tokens")
    }
}
