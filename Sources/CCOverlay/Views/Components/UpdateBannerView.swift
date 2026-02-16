import SwiftUI

struct UpdateBannerView: View {
    let updateService: UpdateService

    @State private var isHovered = false

    var body: some View {
        Group {
            switch updateService.updateState {
            case .updateAvailable(let version):
                availableBanner(version: version)
            case .installing:
                installingBanner
            case .readyToRestart(let version):
                restartBanner(version: version)
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Update Available

    private func availableBanner(version: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("v\(version) available")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            HStack(spacing: 6) {
                Button(action: { updateService.installUpdate() }) {
                    Label("Update Now", systemImage: "arrow.down.to.line")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.borderless)
                .compatGlassCapsule(interactive: true)

                Button(action: { updateService.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .compatGlassRoundedRect(
            cornerRadius: 12,
            tint: .blue.opacity(isHovered ? 0.08 : 0.05)
        )
        .onHover { isHovered = $0 }
    }

    // MARK: - Installing

    private var installingBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text("Installing update...")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .compatGlassRoundedRect(
            cornerRadius: 12,
            tint: .blue.opacity(0.05)
        )
    }

    // MARK: - Ready to Restart

    private func restartBanner(version: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Restart to apply v\(version)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            HStack(spacing: 6) {
                Button(action: { updateService.restartApp() }) {
                    Label("Restart Now", systemImage: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.borderless)
                .compatGlassCapsule(interactive: true)

                Button(action: { updateService.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .compatGlassRoundedRect(
            cornerRadius: 12,
            tint: .green.opacity(isHovered ? 0.08 : 0.05)
        )
        .onHover { isHovered = $0 }
    }
}
