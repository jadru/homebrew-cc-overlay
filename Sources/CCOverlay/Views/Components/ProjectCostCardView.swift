import SwiftUI

/// Compatibility wrapper for callers using the former component name.
struct ProjectCostCardView: View {
    let projects: [ProjectUsageSummary]
    var size: ComponentSize = .standard

    var body: some View {
        ProjectUsageCardView(projects: projects, size: size)
    }
}
