import Testing
import SwiftUI
@testable import CCOverlay

@Suite("Color.usageTint Tests")
struct ColorUsageTintTests {
    private let warningRed = Color(red: 0.97, green: 0.37, blue: 0.19)

    @Test("Returns red for critical usage (≤5%)")
    func criticalUsageTintColor() {
        let color = Color.usageTint(for: 4.0)
        #expect(color == .red)

        let colorAt5 = Color.usageTint(for: 5.0)
        #expect(colorAt5 == .red)
    }

    @Test("Returns custom warning red for low remaining usage (≤15%)")
    func lowRemainingWarningTintColor() {
        let color = Color.usageTint(for: 10.0)
        #expect(color == warningRed)

        let colorAt15 = Color.usageTint(for: 15.0)
        #expect(colorAt15 == warningRed)
    }

    @Test("Returns orange for warning usage (≤30%)")
    func warningUsageTintColor() {
        let color = Color.usageTint(for: 25.0)
        #expect(color == .orange)

        let colorAt30 = Color.usageTint(for: 30.0)
        #expect(colorAt30 == .orange)
    }

    @Test("Returns yellow for moderate usage (≤50%)")
    func moderateUsageTintColor() {
        let color = Color.usageTint(for: 50.0)
        #expect(color == .yellow)

        let colorAt31 = Color.usageTint(for: 31.0)
        #expect(colorAt31 == .yellow)
    }

    @Test("Returns mint for steady usage (≤70%)")
    func steadyUsageTintColor() {
        let color = Color.usageTint(for: 60.0)
        #expect(color == .mint)

        let colorAt70 = Color.usageTint(for: 70.0)
        #expect(colorAt70 == .mint)
    }

    @Test("Returns green for healthy usage (>70%)")
    func healthyUsageTintColor() {
        let color = Color.usageTint(for: 75.0)
        #expect(color == .green)

        let colorAt100 = Color.usageTint(for: 100.0)
        #expect(colorAt100 == .green)
    }

    @Test("Boundary between critical and low warning")
    func boundaryBetweenCriticalAndLowWarning() {
        let color5 = Color.usageTint(for: 5.0)
        let color6 = Color.usageTint(for: 6.0)

        #expect(color5 == .red)
        #expect(color6 == warningRed)
    }

    @Test("Boundary between low warning and warning")
    func boundaryBetweenLowWarningAndWarning() {
        let color15 = Color.usageTint(for: 15.0)
        let color16 = Color.usageTint(for: 16.0)

        #expect(color15 == warningRed)
        #expect(color16 == .orange)
    }

    @Test("Boundary between warning and moderate")
    func boundaryBetweenWarningAndModerate() {
        let color30 = Color.usageTint(for: 30.0)
        let color31 = Color.usageTint(for: 31.0)

        #expect(color30 == .orange)
        #expect(color31 == .yellow)
    }

    @Test("Boundary between moderate and steady")
    func boundaryBetweenModerateAndSteady() {
        let color50 = Color.usageTint(for: 50.0)
        let color51 = Color.usageTint(for: 51.0)

        #expect(color50 == .yellow)
        #expect(color51 == .mint)
    }

    @Test("Boundary between steady and healthy")
    func boundaryBetweenSteadyAndHealthy() {
        let color70 = Color.usageTint(for: 70.0)
        let color71 = Color.usageTint(for: 71.0)

        #expect(color70 == .mint)
        #expect(color71 == .green)
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
