import SwiftUI

/// Shared thin segmented bar used for usage/rate-limit progress visuals.
struct SegmentedProgressBar: View {
    let progress: Double
    let tint: Color
    let height: CGFloat
    var cornerRadius: CGFloat = 2

    private var clampedProgress: Double {
        max(0, min(progress, 100))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.secondary.opacity(0.12))
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(tint)
                    .frame(width: geo.size.width * clampedProgress / 100)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: clampedProgress)
            }
        }
        .frame(height: height)
    }
}
