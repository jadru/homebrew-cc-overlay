import SwiftUI

/// Displays detailed rate limit windows with progress bars and reset countdowns.
struct RateWindowsCardView: View {
    let windows: [DetailedRateWindow]
    var size: Size = .standard

    enum Size {
        case compact
        case standard

        var headerFont: Font {
            switch self {
            case .compact: return .system(size: 10, weight: .semibold)
            case .standard: return .system(size: 11, weight: .medium)
            }
        }

        var padding: CGFloat {
            switch self {
            case .compact: return 10
            case .standard: return 14
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .compact: return 14
            case .standard: return 16
            }
        }
    }

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
        HStack {
            Text("Rate Limits")
                .font(size.headerFont)
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
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
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tint)
                        .frame(width: geo.size.width * max(remainPct / 100.0, 0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: remainPct)
                }
            }
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
