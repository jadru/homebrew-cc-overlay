import SwiftUI

/// Displays detailed rate limit windows with progress bars and reset countdowns.
struct RateWindowsCardView: View {
    let windows: [DetailedRateWindow]
    var size: ComponentSize = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            ForEach(windows) { window in
                windowRow(window)
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackgroundModifier(useGlass: size == .standard, cornerRadius: size.cornerRadius))
    }

    // MARK: - Header

    @ViewBuilder
    private var headerRow: some View {
        CardHeader(
            title: "Rate Limits",
            iconName: "gauge.with.dots.needle.33percent",
            size: size
        )
    }

    // MARK: - Window Row

    @ViewBuilder
    private func windowRow(_ window: DetailedRateWindow) -> some View {
        let remainPct = window.remainingPercent
        let tint = Color.usageTint(for: remainPct)

        VStack(alignment: .leading, spacing: 4) {
            // Label + used percent
            HStack {
                Text(window.label)
                    .font(.system(size: window.isPrimary ? 10 : 9, weight: window.isPrimary ? .semibold : .regular))
                    .foregroundStyle(window.isPrimary ? .primary : .secondary)
                Spacer()
                Text("\(Int(window.usedPercent))% used")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }

            // Progress bar
            SegmentedProgressBar(
                progress: remainPct,
                tint: tint,
                height: window.isPrimary ? 6 : 4
            )
            .frame(height: window.isPrimary ? 6 : 4)

            // Reset countdown
            if let resetsAt = window.resetsAt, resetsAt > Date() {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 7))
                    Text("Resets \(resetsAt, style: .relative)")
                        .font(.system(size: 8))
                }
                .foregroundStyle(.tertiary)
            }
        }
    }
}
