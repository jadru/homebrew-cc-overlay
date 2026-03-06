import SwiftUI

/// A pill-shaped indicator showing a rate limit label and percentage.
struct RatePillView: View {
    let label: String
    let percentage: Int
    var showWarningIcon: Bool = false
    var isSelected: Bool = false
    var maxLabelWidth: CGFloat? = nil
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

    private var labelColor: Color {
        isSelected ? .primary : .secondary
    }

    private var capsuleTint: Color {
        isSelected ? tintColor.opacity(0.18) : Color.primary.opacity(0.05)
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
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: maxLabelWidth, alignment: .leading)
            Text("\(percentage)%")
                .font(size.percentFont)
                .foregroundStyle(tintColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: percentage)
        }
        .fixedSize(horizontal: maxLabelWidth == nil, vertical: true)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .compatGlassCapsule(interactive: isSelected, tint: capsuleTint)
        .opacity(isSelected ? 1.0 : 0.9)
        .animation(.easeInOut(duration: 0.3), value: tintColor)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
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
