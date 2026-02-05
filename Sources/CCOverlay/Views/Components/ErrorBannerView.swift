import SwiftUI

/// A banner view displaying an error with optional retry and dismiss actions.
struct ErrorBannerView: View {
    let error: AppError
    var onRetry: (() -> Void)?
    var onDismiss: (() -> Void)?
    var compact: Bool = false

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            Image(systemName: error.icon)
                .font(.system(size: compact ? 12 : 14))
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                    .foregroundStyle(.primary)

                if !compact {
                    Text(error.message)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                if error.isRetryable, let onRetry {
                    Button(action: onRetry) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }

                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 8 : 10)
        .glassEffect(
            .regular.tint(.red.opacity(isHovered ? 0.08 : 0.05)),
            in: .rect(cornerRadius: compact ? 10 : 12)
        )
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error.title). \(error.message)")
        .accessibilityHint(error.isRetryable ? "Tap retry to try again" : "")
    }
}

/// A simple inline error label for compact spaces (like footers).
struct ErrorLabelView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.system(size: 10))
            .foregroundStyle(.red)
            .accessibilityLabel("Error: \(message)")
    }
}

#Preview("Full Banner") {
    VStack(spacing: 16) {
        ErrorBannerView(
            error: .networkUnavailable,
            onRetry: {},
            onDismiss: {}
        )

        ErrorBannerView(
            error: .apiUnauthorized,
            onDismiss: {}
        )

        ErrorBannerView(
            error: .apiError(statusCode: 500),
            onRetry: {},
            compact: true
        )
    }
    .frame(width: 300)
    .padding()
}

#Preview("Error Label") {
    ErrorLabelView(message: "Failed to fetch usage data")
        .padding()
}
