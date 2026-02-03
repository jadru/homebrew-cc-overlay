import SwiftUI

struct UsageGaugeView: View {
    let percentage: Double
    var remainingText: String? = nil
    var label: String? = nil
    var compact: Bool = false

    var body: some View {
        if compact {
            compactGauge()
        } else {
            fullGauge()
        }
    }

    @ViewBuilder
    private func fullGauge() -> some View {
        VStack(spacing: 8) {
            if let label {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: percentage / 100)
                    .stroke(gaugeColor(percentage), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: percentage)

                VStack(spacing: 2) {
                    Text(NumberFormatting.formatPercentage(percentage))
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    if let remainingText {
                        Text("\(remainingText) left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 80, height: 80)
        }
    }

    @ViewBuilder
    private func compactGauge() -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: percentage / 100)
                    .stroke(gaugeColor(percentage), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 24, height: 24)

            Text(NumberFormatting.formatPercentage(percentage))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
    }

    private func gaugeColor(_ percentage: Double) -> Color {
        if percentage >= 90 { return .red }
        if percentage >= 70 { return .orange }
        return .green
    }
}
