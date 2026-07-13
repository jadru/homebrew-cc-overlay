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
        let url = Self.resourceBundle?.url(
            forResource: iconName,
            withExtension: "svg",
            subdirectory: "ProviderIcons"
        ) ?? Self.resourceBundle?.url(
            forResource: iconName,
            withExtension: "svg"
        )

        guard let url else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static let resourceBundle: Bundle? = {
        let bundleName = "CC-Overlay_CCOverlay"
        let candidates = [
            Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
            Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle"),
        ]

        return candidates.compactMap { $0 }.lazy.compactMap(Bundle.init(url:)).first
    }()
}
