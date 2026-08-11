import AppKit
import SwiftUI
import XCTest
@testable import CCOverlay

@MainActor
final class MenuBarViewStateTests: XCTestCase {
    func testReadyDataRemainsVisibleDuringRefresh() {
        let state = MenuBarView.resolvePanelState(
            activeProviders: [.claudeCode],
            availableProviders: [.claudeCode],
            isLoading: true,
            hasError: true
        )

        XCTAssertEqual(state, .ready)
    }

    func testUnavailableProviderShowsLoadingWhileFirstSnapshotLoads() {
        let state = MenuBarView.resolvePanelState(
            activeProviders: [.codex],
            availableProviders: [],
            isLoading: true,
            hasError: false
        )

        XCTAssertEqual(state, .loading)
    }

    func testUnavailableProviderExposesFetchFailure() {
        let state = MenuBarView.resolvePanelState(
            activeProviders: [.codex],
            availableProviders: [],
            isLoading: false,
            hasError: true
        )

        XCTAssertEqual(state, .failed)
    }

    func testEmptyDetectionShowsNoProvidersState() {
        let state = MenuBarView.resolvePanelState(
            activeProviders: [],
            availableProviders: [],
            isLoading: false,
            hasError: false
        )

        XCTAssertEqual(state, .noProviders)
    }

    func testConnectedProviderWithoutCurrentWindowShowsNoUsageState() {
        let state = MenuBarView.resolvePanelState(
            activeProviders: [.claudeCode],
            availableProviders: [],
            isLoading: false,
            hasError: false
        )

        XCTAssertEqual(state, .noUsage)
    }

    func testSingleWeeklyCodexWindowUsesCompactPanelHeight() {
        let data = ProviderUsageData(
            provider: .codex,
            isAvailable: true,
            usedPercentage: 1,
            remainingPercentage: 99,
            primaryWindowLabel: "1w",
            rateLimitBuckets: [
                RateBucket(label: "1w", utilization: 1),
                RateBucket(label: "Spark", utilization: 0),
            ]
        )

        XCTAssertEqual(
            MenuBarView.readyPanelMinHeight(for: data),
            DesignTokens.Layout.menuBarPanelCompactMinHeight
        )
    }

    func testFiveHourAndWeeklyWindowsKeepStandardPanelHeight() {
        let data = ProviderUsageData(
            provider: .codex,
            isAvailable: true,
            usedPercentage: 15,
            remainingPercentage: 85,
            primaryWindowLabel: "5h",
            rateLimitBuckets: [
                RateBucket(label: "5h", utilization: 15),
                RateBucket(label: "1w", utilization: 1),
            ]
        )

        XCTAssertEqual(
            MenuBarView.readyPanelMinHeight(for: data),
            DesignTokens.Layout.menuBarPanelMinHeight
        )
    }

    func testUsageHistoryExpandsTheReadyPanelWithoutExceedingMaximum() {
        XCTAssertEqual(
            MenuBarView.workflowPanelMinHeight(
                baseHeight: DesignTokens.Layout.menuBarPanelCompactMinHeight,
                historyCount: 12
            ),
            515
        )
        XCTAssertEqual(
            MenuBarView.workflowPanelMinHeight(
                baseHeight: DesignTokens.Layout.menuBarPanelMinHeight,
                historyCount: 12
            ),
            615
        )
    }

    func testEmptyPanelRendersMessageAndRecoveryActions() {
        let accountContext = makeCodexAccountContext()
        let view = MenuBarView(
            multiService: MultiProviderUsageService(),
            codexProfileStore: accountContext.store,
            codexAccountMonitor: accountContext.monitor,
            settings: AppSettings(),
            patchProgress: PatchProgressStore(),
            updateService: UpdateService()
        )
        let hostingView = NSHostingView(rootView: view)
        let size = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertEqual(size.width, DesignTokens.Layout.menuBarPanelWidth, accuracy: 1)
        XCTAssertGreaterThanOrEqual(size.height, DesignTokens.Layout.menuBarPanelEmptyMinHeight)
        XCTAssertLessThanOrEqual(size.height, DesignTokens.Layout.menuBarPanelMaxHeight)

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return XCTFail("Could not create an empty-state bitmap")
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        let messageCoverage = meanAlpha(in: bitmap, x: 0.18..<0.82, y: 0.28..<0.74)
        let actionCoverage = meanAlpha(in: bitmap, x: 0.02..<0.62, y: 0.66..<0.98)
        XCTAssertGreaterThan(messageCoverage, 0.003)
        XCTAssertGreaterThan(actionCoverage, 0.003)
    }

    private func makeCodexAccountContext() -> (
        store: CodexAccountProfileStore,
        monitor: CodexAccountMonitor
    ) {
        let suiteName = "MenuBarViewStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = CodexAccountProfileStore(defaults: defaults, userHome: "/Users/tester")
        return (
            store,
            CodexAccountMonitor(profileStore: store, binaryPathProvider: { nil })
        )
    }

    func testCodexTimelineRendersBankedFullResetRow() {
        let data = ProviderUsageData(
            provider: .codex,
            isAvailable: true,
            usedPercentage: 20,
            remainingPercentage: 80,
            primaryWindowLabel: "5h",
            rateLimitBuckets: [
                RateBucket(label: "5h", utilization: 20),
                RateBucket(label: "1w", utilization: 10),
            ],
            creditsInfo: CreditsDisplayInfo(
                planType: "Pro",
                hasCredits: false,
                unlimited: false,
                balance: nil,
                extraUsageEnabled: false,
                resetCreditsAvailable: 1,
                resetCreditsApplicable: 0
            )
        )
        let hostingView = NSHostingView(
            rootView: UsageTimelineView(data: data).frame(width: 320)
        )

        XCTAssertEqual(hostingView.fittingSize.width, 320, accuracy: 1)
        XCTAssertGreaterThan(hostingView.fittingSize.height, 180)
        XCTAssertLessThan(hostingView.fittingSize.height, 420)
    }

    func testHistoryComponentRenders() {
        let now = Date()
        let history = NSHostingView(
            rootView: UsageHistoryChartView(
                points: [
                    UsageHistoryPoint(timestamp: now.addingTimeInterval(-600), remainingPercentage: 80),
                    UsageHistoryPoint(timestamp: now, remainingPercentage: 60),
                ],
                forecast: ProviderHeadroomForecast(
                    exhaustionAt: now.addingTimeInterval(3_600),
                    consumptionPerHour: 20,
                    sampleCount: 2,
                    resetsBeforeExhaustion: false
                )
            )
            .frame(width: 320)
        )
        XCTAssertGreaterThan(history.fittingSize.height, 60)
    }

    func testOnboardingFitsItsWindow() {
        let view = OnboardingView(
            settings: AppSettings(),
            multiService: MultiProviderUsageService(),
            patchProgress: PatchProgressStore(),
            onComplete: {}
        )
        let hostingView = NSHostingView(rootView: view)
        let size = hostingView.fittingSize

        XCTAssertEqual(size.width, 520, accuracy: 1)
        XCTAssertEqual(size.height, 520, accuracy: 1)
    }

    private func meanAlpha(
        in bitmap: NSBitmapImageRep,
        x xRange: Range<Double>,
        y yRange: Range<Double>
    ) -> Double {
        let minX = Int(Double(bitmap.pixelsWide) * xRange.lowerBound)
        let maxX = Int(Double(bitmap.pixelsWide) * xRange.upperBound)
        let minY = Int(Double(bitmap.pixelsHigh) * yRange.lowerBound)
        let maxY = Int(Double(bitmap.pixelsHigh) * yRange.upperBound)
        let xBounds = minX..<maxX
        let yBounds = minY..<maxY

        var totalAlpha: CGFloat = 0
        var sampleCount = 0
        for y in yBounds {
            for x in xBounds {
                totalAlpha += bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
                sampleCount += 1
            }
        }
        return sampleCount > 0 ? Double(totalAlpha) / Double(sampleCount) : 0
    }
}
