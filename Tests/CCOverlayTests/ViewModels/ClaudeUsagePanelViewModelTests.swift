import Testing
import SwiftUI
@testable import CCOverlay

@Suite("Color.usageTint Tests")
struct ColorUsageTintTests {

    @Test("Returns red for critical usage (≤10%)")
    func criticalUsageTintColor() {
        let color = Color.usageTint(for: 5.0)
        #expect(color == .red)

        let colorAt10 = Color.usageTint(for: 10.0)
        #expect(colorAt10 == .red)
    }

    @Test("Returns orange for warning usage (≤30%)")
    func warningUsageTintColor() {
        let color = Color.usageTint(for: 25.0)
        #expect(color == .orange)

        let colorAt30 = Color.usageTint(for: 30.0)
        #expect(colorAt30 == .orange)
    }

    @Test("Returns yellow for moderate usage (≤60%)")
    func moderateUsageTintColor() {
        let color = Color.usageTint(for: 50.0)
        #expect(color == .yellow)

        let colorAt60 = Color.usageTint(for: 60.0)
        #expect(colorAt60 == .yellow)
    }

    @Test("Returns green for healthy usage (>60%)")
    func healthyUsageTintColor() {
        let color = Color.usageTint(for: 75.0)
        #expect(color == .green)

        let colorAt100 = Color.usageTint(for: 100.0)
        #expect(colorAt100 == .green)
    }

    @Test("Boundary between critical and warning")
    func boundaryBetweenCriticalAndWarning() {
        let color10 = Color.usageTint(for: 10.0)
        let color11 = Color.usageTint(for: 11.0)

        #expect(color10 == .red)
        #expect(color11 == .orange)
    }

    @Test("Boundary between warning and moderate")
    func boundaryBetweenWarningAndModerate() {
        let color30 = Color.usageTint(for: 30.0)
        let color31 = Color.usageTint(for: 31.0)

        #expect(color30 == .orange)
        #expect(color31 == .yellow)
    }

    @Test("Boundary between moderate and healthy")
    func boundaryBetweenModerateAndHealthy() {
        let color60 = Color.usageTint(for: 60.0)
        let color61 = Color.usageTint(for: 61.0)

        #expect(color60 == .yellow)
        #expect(color61 == .green)
    }
}

@Suite("Color.rateLimitTint Tests")
struct ColorRateLimitTintTests {

    @Test("Returns red for critical rate limit (≥90%)")
    func criticalRateLimitTint() {
        let color = Color.rateLimitTint(for: 95.0)
        #expect(color == .red)

        let colorAt90 = Color.rateLimitTint(for: 90.0)
        #expect(colorAt90 == .red)
    }

    @Test("Returns orange for warning rate limit (≥70%)")
    func warningRateLimitTint() {
        let color = Color.rateLimitTint(for: 80.0)
        #expect(color == .orange)

        let colorAt70 = Color.rateLimitTint(for: 70.0)
        #expect(colorAt70 == .orange)
    }

    @Test("Returns secondary for normal rate limit (<70%)")
    func normalRateLimitTint() {
        let color = Color.rateLimitTint(for: 50.0)
        #expect(color == .secondary)

        let colorAt69 = Color.rateLimitTint(for: 69.0)
        #expect(colorAt69 == .secondary)
    }
}

@Suite("AppError Tests")
struct AppErrorTests {

    @Test("Network unavailable error properties")
    func networkUnavailableProperties() {
        let error = AppError.networkUnavailable

        #expect(error.title == "Network Unavailable")
        #expect(error.icon == "wifi.slash")
        #expect(error.isRetryable == true)
    }

    @Test("API error properties")
    func apiErrorProperties() {
        let error = AppError.apiError(statusCode: 500)

        #expect(error.title == "API Error (500)")
        #expect(error.icon == "exclamationmark.icloud")
        #expect(error.isRetryable == true)
    }

    @Test("Unauthorized error is not retryable")
    func unauthorizedNotRetryable() {
        let error = AppError.apiUnauthorized

        #expect(error.title == "Unauthorized")
        #expect(error.isRetryable == false)
    }

    @Test("Creates network error from message")
    func createsNetworkErrorFromMessage() {
        let error = AppError.from("Network connection failed")

        #expect(error == .networkUnavailable)
    }

    @Test("Creates unauthorized error from message")
    func createsUnauthorizedErrorFromMessage() {
        let error = AppError.from("401 Unauthorized")

        #expect(error == .apiUnauthorized)
    }

    @Test("Creates unknown error for unrecognized message")
    func createsUnknownErrorForUnrecognized() {
        let error = AppError.from("Something went wrong")

        if case .unknown(let message) = error {
            #expect(message == "Something went wrong")
        } else {
            Issue.record("Expected unknown error type")
        }
    }
}

@Suite("GaugeCardView.RateLimitBucket Tests")
struct RateLimitBucketTests {

    @Test("Bucket has correct label")
    func bucketHasCorrectLabel() {
        let bucket = GaugeCardView.RateLimitBucket(label: "5h", percentage: 45)

        #expect(bucket.label == "5h")
    }

    @Test("Bucket dimmed default is false")
    func bucketDimmedDefaultIsFalse() {
        let bucket = GaugeCardView.RateLimitBucket(label: "7d", percentage: 30)

        #expect(bucket.dimmed == false)
    }

    @Test("Bucket can be dimmed")
    func bucketCanBeDimmed() {
        let bucket = GaugeCardView.RateLimitBucket(label: "7d", percentage: 30, dimmed: true)

        #expect(bucket.dimmed == true)
    }
}
