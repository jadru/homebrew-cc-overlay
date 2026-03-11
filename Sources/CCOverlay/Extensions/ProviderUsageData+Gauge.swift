import Foundation

extension ProviderUsageData {
    var gaugeRateLimitBuckets: [GaugeCardView.RateLimitBucket] {
        rateLimitBuckets.map { bucket in
            GaugeCardView.RateLimitBucket(
                label: bucket.label,
                percentage: Int(100 - min(max(bucket.utilization, 0), 100)),
                showWarning: bucket.isWarning
            )
        }
    }

    var gaugeWarningPercentage: Int? {
        guard let weeklyBucket = rateLimitBuckets.first(where: { $0.label == "7d" || $0.label == "1w" }) else {
            return nil
        }
        return Int(min(max(weeklyBucket.utilization, 0), 100))
    }
}
