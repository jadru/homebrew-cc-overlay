import SwiftUI

struct PatchGearImage: View {
    let gear: PatchGear
    var size: CGFloat

    var body: some View {
        Group {
            if let image = PatchArtworkLoader.image(named: gear.assetFilename) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Image(systemName: gear.symbolName)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
