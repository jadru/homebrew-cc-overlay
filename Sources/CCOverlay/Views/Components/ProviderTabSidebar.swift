import SwiftUI

/// Vertical icon-based sidebar for switching between providers and accessing settings.
struct ProviderTabSidebar: View {
    let providers: [CLIProvider]
    let activeProviders: Set<CLIProvider>
    @Binding var selectedProvider: CLIProvider?
    var onSettingsTapped: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(providers) { provider in
                tabButton(for: provider)
            }

            Spacer()

            settingsButton
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

        Button {
            withAnimation(.snappy(duration: 0.2)) {
                selectedProvider = provider
            }
        } label: {
            Image(systemName: provider.iconName)
                .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .opacity(isActive ? 1.0 : 0.35)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.18))
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.2), value: isSelected)
        .help(provider.rawValue)
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
    }
}
