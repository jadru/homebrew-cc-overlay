import SwiftUI

/// Compact health summary for each provider including detection/auth status and request timing.
struct ProviderHealthCardView: View {
    let data: ProviderUsageData
    var size: ComponentSize = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardHeader(
                title: "Provider Health",
                iconName: "heart.text.square",
                size: size
            )

            statusRow(label: "Detection", value: data.isDetected ? "Detected" : "Not detected")
            statusRow(label: "Authentication", value: data.isAuthenticated ? "Active" : "Not active")
            statusRow(label: "Last success", value: lastSuccessText)
            statusRow(label: "Last response", value: responseText)

            if let error = data.error {
                statusRow(label: "Last error", value: error, valueColor: .orange)
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackgroundModifier(useGlass: size == .standard, cornerRadius: size.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Provider health: detected \(data.isDetected ? "yes" : "no"), authentication \(data.isAuthenticated ? "yes" : "no"), \(lastSuccessText), \(responseText)"
        )
    }

    private var lastSuccessText: String {
        if let timestamp = data.lastSuccessfulRefresh {
            return timestamp.formatted(.relative(presentation: .named))
        }
        return "No successful refresh yet"
    }

    private var responseText: String {
        guard let duration = data.lastResponseDuration else {
            return "No response sample"
        }
        let ms = Int((duration * 1000).rounded())
        return "\(ms) ms"
    }

    @ViewBuilder
    private func statusRow(label: String, value: String, valueColor: Color = .secondary) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            Spacer()

            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
        }
    }
}
