import SwiftUI

/// A focused provider usage view for the menu bar panel.
struct ProviderSectionView: View {
    let data: ProviderUsageData

    var body: some View {
        UsageTimelineView(data: data)
        .id(data.provider)
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        )
    }
}
