import SwiftUI

enum PatchSprite: String, Sendable {
    case idle
    case wag
    case sniff
    case alert
    case sleep
    case celebrate

    var assetFilename: String { "patch-\(rawValue)" }

    static func forMood(_ mood: PatchPresentation.Mood, frameIndex: Int) -> PatchSprite {
        switch mood {
        case .offline, .resting: return .sleep
        case .watchful: return frameIndex.isMultiple(of: 2) ? .alert : .sniff
        case .focused: return frameIndex.isMultiple(of: 2) ? .idle : .wag
        case .thriving: return frameIndex.isMultiple(of: 2) ? .wag : .celebrate
        }
    }
}

struct PatchSpriteImage: View {
    let sprite: PatchSprite
    var width: CGFloat

    var body: some View {
        Group {
            if let image = PatchArtworkLoader.image(named: sprite.assetFilename) {
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
        .frame(width: width)
        .accessibilityHidden(true)
    }
}
