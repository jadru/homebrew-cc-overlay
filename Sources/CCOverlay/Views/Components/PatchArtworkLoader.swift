import AppKit

/// Loads every Patch raster from one package resource directory. This prevents
/// the workshop, sprites, and gear thumbnails from drifting into mixed styles.
enum PatchArtworkLoader {
    static func image(named name: String) -> NSImage? {
        guard let resourceBundle else { return nil }

        let url = resourceBundle.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "PatchAssets"
        ) ?? resourceBundle.url(forResource: name, withExtension: "png")

        return url.flatMap(NSImage.init(contentsOf:))
    }

    private static let resourceBundle: Bundle? = {
        let bundleName = "CC-Overlay_CCOverlay"
        let candidates = [
            Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
            Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle"),
        ]
        .compactMap { $0 }
        .lazy
        .compactMap(Bundle.init(url:))
        .first
        return candidates
    }()
}
