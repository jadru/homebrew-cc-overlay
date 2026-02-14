import SwiftUI

struct ProviderBadge: View {
    let provider: CLIProvider

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: provider.iconName)
                .font(.system(size: 10))
            Text(provider.rawValue)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}
