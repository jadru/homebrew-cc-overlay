import SwiftUI

/// A minimal sparkline chart rendered with SwiftUI Path.
struct SparklineView: View {
    let dataPoints: [Double]
    var lineColor: Color = .accentColor
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            if dataPoints.count >= 2 {
                sparklinePath(in: geo.size)
                    .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func sparklinePath(in size: CGSize) -> Path {
        let minVal = dataPoints.min() ?? 0
        let maxVal = dataPoints.max() ?? 1
        let range = max(maxVal - minVal, 0.001)

        return Path { path in
            for (index, value) in dataPoints.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                let y = size.height * (1 - CGFloat((value - minVal) / range))

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}
