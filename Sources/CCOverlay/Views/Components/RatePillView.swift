import SwiftUI

/// A pill-shaped indicator showing a rate limit label and percentage.
struct RatePillView: View {
    let label: String
    let percentage: Int
    var showWarningIcon: Bool = false
    var size: Size = .regular

    enum Size {
        case compact  // For PillView (8pt font)
        case regular  // For ClaudeUsagePanelView (9pt font)
        case large    // For MenuBarView (10pt font)

        var labelFont: Font {
            switch self {
            case .compact: return .system(size: 9, weight: .medium)
            case .regular: return .system(size: 9, weight: .medium)
            case .large: return .system(size: 10)
            }
        }

        var percentFont: Font {
            switch self {
            case .compact: return .system(size: 9, weight: .semibold, design: .monospaced)
            case .regular: return .system(size: 9, weight: .semibold, design: .monospaced)
            case .large: return .system(size: 10, weight: .semibold, design: .monospaced)
            }
        }

        var spacing: CGFloat {
            switch self {
            case .compact: return 3
            case .regular, .large: return 3
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .compact: return 7
            case .regular, .large: return 8
            }
        }

        var verticalPadding: CGFloat { 4 }
    }

    private var tintColor: Color {
        Color.usageTint(for: Double(percentage))
    }

    private var compactLabel: String {
        if label.contains("Codex-Spark") { return "Spark" }
        if label.contains("Sonnet") { return "Sonnet" }
        if label.count <= 14 { return label }
        return String(label.prefix(12)) + "…"
    }

    private var labelMaxWidth: CGFloat {
        switch size {
        case .compact: return 72
        case .regular: return 88
        case .large: return 118
        }
    }

    var body: some View {
        HStack(spacing: size.spacing) {
            if showWarningIcon {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: size == .compact ? 7 : 8))
                    .foregroundStyle(.orange)
            }
            Text(compactLabel)
                .font(size.labelFont)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: labelMaxWidth, alignment: .leading)
            Text("\(percentage)%")
                .font(size.percentFont)
                .foregroundStyle(tintColor)
                .layoutPriority(1)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: percentage)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .compatGlassCapsule()
        .animation(.easeInOut(duration: 0.3), value: tintColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) window \(percentage) percent remaining")
    }
}

#Preview {
    VStack(spacing: 10) {
        RatePillView(label: "5h", percentage: 45, size: .large)
        RatePillView(label: "7d", percentage: 75, size: .regular)
        RatePillView(label: "Sonnet", percentage: 95, showWarningIcon: true, size: .compact)
    }
    .padding()
}
