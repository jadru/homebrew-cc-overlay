import SwiftUI

/// Horizontal provider summary card for quick cross-provider comparison.
struct ProviderSummaryCardView: View {
    enum Size {
        case standard
        case compact

        var outerPadding: CGFloat {
            switch self {
            case .standard: return 6
            case .compact: return 0
            }
        }

        var columnMinHeight: CGFloat {
            switch self {
            case .standard: return 88
            case .compact: return 30
            }
        }

        var columnHorizontalPadding: CGFloat {
            switch self {
            case .standard: return 8
            case .compact: return 3
            }
        }

        var columnMinWidth: CGFloat? {
            switch self {
            case .standard: return nil
            case .compact: return 38
            }
        }

        var labelFont: Font {
            switch self {
            case .standard: return .system(size: 11, weight: .semibold)
            case .compact: return .system(size: 9, weight: .semibold)
            }
        }

        var showsSelection: Bool {
            switch self {
            case .standard: return true
            case .compact: return false
            }
        }

        var percentageFont: Font {
            switch self {
            case .standard: return .system(size: 13, weight: .bold, design: .rounded)
            case .compact: return .system(size: 11, weight: .bold, design: .rounded)
            }
        }

        var resetFont: Font {
            switch self {
            case .standard: return .system(size: 11, weight: .medium, design: .monospaced)
            case .compact: return .system(size: 9, weight: .medium, design: .monospaced)
            }
        }

        var fallbackResetFont: Font {
            switch self {
            case .standard: return .system(size: 11, weight: .medium)
            case .compact: return .system(size: 9, weight: .medium, design: .monospaced)
            }
        }

        var selectionCornerRadius: CGFloat {
            switch self {
            case .standard: return 12
            case .compact: return 8
            }
        }

        var dividerVerticalPadding: CGFloat {
            switch self {
            case .standard: return 10
            case .compact: return 4
            }
        }

        var rowSpacing: CGFloat {
            switch self {
            case .standard: return 6
            case .compact: return 2
            }
        }
    }

    let allProviderData: [(CLIProvider, ProviderUsageData)]
    @Binding var selectedProvider: CLIProvider?
    let activeProviders: Set<CLIProvider>
    var size: Size = .standard
    var showsCardBackground = true

    var body: some View {
        Group {
            if showsCardBackground {
                content
                    .padding(size.outerPadding)
                    .frame(maxWidth: .infinity)
                    .cardBackground(useGlass: true, cornerRadius: 16)
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: 0) {
            ForEach(Array(allProviderData.enumerated()), id: \.element.0) { index, element in
                let provider = element.0
                let data = element.1

                providerColumn(provider: provider, data: data)

                if index < allProviderData.count - 1 {
                    Rectangle()
                        .fill(Color.dividerSubtle)
                        .frame(width: 0.5)
                        .padding(.vertical, size.dividerVerticalPadding)
                }
            }
        }
    }

    @ViewBuilder
    private func providerColumn(provider: CLIProvider, data: ProviderUsageData) -> some View {
        let isSelected = selectedProvider == provider
        let isActive = activeProviders.contains(provider)
        let isAvailable = isActive && data.isAvailable
        let tint = isAvailable ? Color.usageTint(for: data.remainingPercentage) : .secondary

        Button {
            withAnimation(DesignTokens.Animation.selection) {
                selectedProvider = provider
            }
        } label: {
            VStack(spacing: size.rowSpacing) {
                Text(provider.shortLabel)
                    .font(size.labelFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if isAvailable {
                    Text(NumberFormatting.formatPercentage(data.remainingPercentage))
                        .font(size.percentageFont)
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                } else {
                    Text("—")
                        .font(size.percentageFont)
                        .foregroundStyle(.tertiary)
                }

                resetText(for: data, isActive: isAvailable)
            }
            .frame(minWidth: size.columnMinWidth, maxWidth: .infinity, minHeight: size.columnMinHeight)
            .padding(.horizontal, size.columnHorizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: size.selectionCornerRadius, style: .continuous)
                    .fill(isSelected && size.showsSelection ? tint.opacity(0.08) : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: size.selectionCornerRadius, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(isAvailable ? 1.0 : 0.45)
        .accessibilityLabel(provider.rawValue)
        .accessibilityValue(isAvailable ? NumberFormatting.formatPercentage(data.remainingPercentage) : "Setup required")
        .accessibilityHint("Select provider")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func resetText(for data: ProviderUsageData, isActive: Bool) -> some View {
        if !isActive {
            Text("—")
                .font(size.fallbackResetFont)
                .foregroundStyle(.tertiary)
        } else if let resetsAt = data.resetsAt, resetsAt > .now {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let remaining = resetsAt.timeIntervalSince(context.date)
                Text(remaining > 0 ? DurationFormatting.compactReset(remaining) : data.primaryWindowLabel)
                    .font(size.resetFont)
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText(countsDown: true))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        } else {
            Text(data.primaryWindowLabel)
                .font(size.fallbackResetFont)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

}

#Preview {
    @Previewable @State var selectedProvider: CLIProvider? = .claudeCode

    ProviderSummaryCardView(
        allProviderData: [
            (
                .claudeCode,
                ProviderUsageData(
                    provider: .claudeCode,
                    isAvailable: true,
                    usedPercentage: 27,
                    remainingPercentage: 73,
                    primaryWindowLabel: "5h",
                    resetsAt: .now.addingTimeInterval(3 * 3600 + 5 * 60)
                )
            ),
            (
                .codex,
                ProviderUsageData(
                    provider: .codex,
                    isAvailable: true,
                    usedPercentage: 55,
                    remainingPercentage: 45,
                    primaryWindowLabel: "Daily",
                    resetsAt: .now.addingTimeInterval(12 * 3600 + 30 * 60)
                )
            )
        ],
        selectedProvider: $selectedProvider,
        activeProviders: [.claudeCode, .codex]
    )
    .frame(width: 320)
    .padding()
}
