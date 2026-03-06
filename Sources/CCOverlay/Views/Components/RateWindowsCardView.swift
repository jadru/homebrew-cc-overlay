import SwiftUI

/// Displays detailed rate limit windows with progress bars and reset countdowns.
struct RateWindowsCardView: View {
    let windows: [DetailedRateWindow]
    var maxVisibleRows: Int? = nil
    var size: ComponentSize = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            ForEach(displayedWindows) { window in
                windowRow(window)
            }
            if let maxVisibleRows, windows.count > maxVisibleRows {
                Text("+ \(windows.count - maxVisibleRows) more")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackgroundModifier(useGlass: size == .standard, cornerRadius: size.cornerRadius))
    }

    private var displayedWindows: ArraySlice<DetailedRateWindow> {
        guard let maxVisibleRows else {
            return windows[...]
        }
        return windows.prefix(maxVisibleRows)
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
        let accessibilityText = {
            let labelPrefix = "\(window.label) \(Int(window.usedPercent)) percent used"
            guard let resetsAt = window.resetsAt, resetsAt > Date() else {
                return labelPrefix
            }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return "\(labelPrefix), resets \(formatter.localizedString(for: resetsAt, relativeTo: Date()))"
        }()

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
                        .accessibilityHidden(true)
                    Text("Resets \(resetsAt, style: .relative)")
                        .font(.system(size: 8))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }
}
