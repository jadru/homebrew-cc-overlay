import AppKit
import SwiftUI

struct ProviderIconView: View {
    let provider: CLIProvider
    var size: CGFloat
    var fallbackColor: Color = .secondary
    var fallbackWeight: Font.Weight = .semibold

    private var iconName: String {
        switch provider {
        case .claudeCode: return "claude-code"
        case .codex: return "codex"
        }
    }

    var body: some View {
        if let image = providerImage {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: provider.iconName)
                .font(.system(size: size, weight: fallbackWeight))
                .foregroundStyle(fallbackColor)
                .frame(width: size, height: size)
        }
    }

    private var providerImage: NSImage? {
        let url = Bundle.module.url(
            forResource: iconName,
            withExtension: "svg",
            subdirectory: "ProviderIcons"
        ) ?? Bundle.module.url(
            forResource: iconName,
            withExtension: "svg"
        )

        guard let url else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
