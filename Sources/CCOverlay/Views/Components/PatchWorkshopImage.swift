import SwiftUI

struct PatchWorkshopImage: View {
    let workshop: PatchWorkshop
    var size: CGFloat

    var body: some View {
        Group {
            if let image = PatchArtworkLoader.image(named: workshop.assetFilename) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .interpolation(.none)
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
