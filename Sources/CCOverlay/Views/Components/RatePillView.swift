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
            case .compact: return .system(size: 8, weight: .medium)
            case .regular: return .system(size: 9, weight: .medium)
            case .large: return .system(size: 10)
            }
        }

        var percentFont: Font {
            switch self {
            case .compact: return .system(size: 8, weight: .semibold, design: .monospaced)
            case .regular: return .system(size: 9, weight: .semibold, design: .monospaced)
            case .large: return .system(size: 10, weight: .semibold, design: .monospaced)
            }
        }

        var spacing: CGFloat {
            switch self {
            case .compact: return 2
            case .regular, .large: return 3
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .compact: return 6
            case .regular, .large: return 8
            }
        }

        var verticalPadding: CGFloat { 4 }
    }

    private var tintColor: Color {
        Color.rateLimitTint(for: Double(percentage))
    }

    var body: some View {
        HStack(spacing: size.spacing) {
            if showWarningIcon {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: size == .compact ? 7 : 8))
                    .foregroundStyle(.orange)
            }
            Text(label)
                .font(size.labelFont)
                .foregroundStyle(.tertiary)
            Text("\(percentage)%")
                .font(size.percentFont)
                .foregroundStyle(tintColor)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: percentage)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .glassEffect(.regular, in: .capsule)
        .animation(.easeInOut(duration: 0.3), value: tintColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) window at \(percentage) percent")
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
