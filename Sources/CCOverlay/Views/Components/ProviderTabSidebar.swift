import AppKit
import SwiftUI

/// Vertical icon-based sidebar for switching between providers and accessing settings.
struct ProviderTabSidebar: View {
    let providers: [CLIProvider]
    let activeProviders: Set<CLIProvider>
    let pausedProviders: Set<CLIProvider>
    let providerErrors: [CLIProvider: String]
    @Binding var selectedProvider: CLIProvider?
    var onSettingsTapped: () -> Void
    var onPauseResumeTapped: (CLIProvider) -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(providers) { provider in
                tabButton(for: provider)
            }

            Spacer()

            settingsButton
            quitButton
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 5)
        .frame(width: 44)
    }

    // MARK: - Provider Tab Button

    @ViewBuilder
    private func tabButton(for provider: CLIProvider) -> some View {
        let isActive = activeProviders.contains(provider)
        let isSelected = selectedProvider == provider
        let isPaused = pausedProviders.contains(provider)
        let hasError = providerErrors[provider] != nil

        Button {
            withAnimation(.snappy(duration: 0.2)) {
                selectedProvider = provider
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
                    .padding(4)

                if isPaused || hasError {
                    HStack(spacing: 2) {
                        if hasError {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.orange)
                        }

                        if isPaused {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(3)
                    .background(.ultraThinMaterial, in: Circle())
                    .accessibilityHidden(true)
                    .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.borderless)
        .opacity((isActive ? 1.0 : 0.35) * (isPaused ? 0.45 : 1.0))
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.18))
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.2), value: isSelected)
        .contextMenu {
            Button {
                onPauseResumeTapped(provider)
            } label: {
                Label(
                    isPaused ? "Resume" : "Pause",
                    systemImage: isPaused ? "play.fill" : "pause.fill"
                )
            }
        }
        .help(provider.rawValue)
        .accessibilityLabel(
            "\(provider.rawValue)"
            + (isPaused ? ", paused" : "")
            + (hasError ? ", has warning" : "")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Settings

    @ViewBuilder
    private var settingsButton: some View {
        Button(action: onSettingsTapped) {
            Image(systemName: "gear")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help("Settings")
        .accessibilityLabel("Settings")
    }

    @ViewBuilder
    private var quitButton: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Image(systemName: "power")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help("Quit")
        .accessibilityLabel("Quit")
    }
}
