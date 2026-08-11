import AppKit
import SwiftUI

enum CompanionArtworkLoader {
    static func image(named name: String) -> NSImage? {
        guard let resourceBundle else { return nil }
        let url = resourceBundle.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "CompanionAssets"
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

struct CompanionPetImage: View {
    let pet: CompanionPet
    var width: CGFloat
    var patchSprite: PatchSprite? = nil
    var careAccessory: CompanionCareAccessory? = nil
    var bodyParallax: CGSize = .zero

    var body: some View {
        ZStack {
            Group {
                if let careAccessory,
                   let fittedAsset = pet.fittedCareAssetFilename(for: careAccessory),
                   let image = CompanionArtworkLoader.image(named: fittedAsset) {
                    Image(nsImage: image)
                        .resizable()
                        .renderingMode(.original)
                        .interpolation(.none)
                        .scaledToFit()
                } else if pet.usesPatchAnimation, let patchSprite {
                    PatchSpriteImage(sprite: patchSprite, width: width)
                } else if let image = CompanionArtworkLoader.image(named: pet.assetFilename) {
                    Image(nsImage: image)
                        .resizable()
                        .renderingMode(.original)
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(.orange)
                }
            }
            .offset(x: bodyParallax.width, y: bodyParallax.height)
        }
        .frame(width: width, height: width)
        .accessibilityHidden(true)
    }
}

struct CompanionCareAccessoryThumbnail: View {
    let accessory: CompanionCareAccessory
    var size: CGFloat

    var body: some View {
        Group {
            if let image = CompanionArtworkLoader.image(named: accessory.assetFilename) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Image(systemName: accessory.symbolName)
                    .foregroundStyle(.orange)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
