import AppKit
import SwiftUI
import XCTest
@testable import CCOverlay

@MainActor
final class DashboardPanelViewStateTests: XCTestCase {
    func testReadyDataRemainsVisibleDuringRefresh() {
        let state = DashboardPanelView.resolvePanelState(
            activeProviders: [.claudeCode],
            availableProviders: [.claudeCode],
            isLoading: true,
            hasError: true
        )

        XCTAssertEqual(state, .ready)
    }

    func testUnavailableProviderShowsLoadingWhileFirstSnapshotLoads() {
        let state = DashboardPanelView.resolvePanelState(
            activeProviders: [.codex],
            availableProviders: [],
            isLoading: true,
            hasError: false
        )

        XCTAssertEqual(state, .loading)
    }

    func testUnavailableProviderExposesFetchFailure() {
        let state = DashboardPanelView.resolvePanelState(
            activeProviders: [.codex],
            availableProviders: [],
            isLoading: false,
            hasError: true
        )

        XCTAssertEqual(state, .failed)
    }

    func testEmptyDetectionShowsNoProvidersState() {
        let state = DashboardPanelView.resolvePanelState(
            activeProviders: [],
            availableProviders: [],
            isLoading: false,
            hasError: false
        )

        XCTAssertEqual(state, .noProviders)
    }

    func testConnectedProviderWithoutCurrentWindowShowsNoUsageState() {
        let state = DashboardPanelView.resolvePanelState(
            activeProviders: [.claudeCode],
            availableProviders: [],
            isLoading: false,
            hasError: false
        )

        XCTAssertEqual(state, .noUsage)
    }

    func testSystemDashboardUsesItsIntrinsicContentHeight() {
        let view = DashboardPanelView(
            multiService: MultiProviderUsageService(),
            settings: AppSettings(),
            systemMetrics: SystemMetricsService(),
            dockerStorage: DockerStorageService(),
            updateService: UpdateService()
        )
        let hostingView = NSHostingView(rootView: view)
        let size = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertEqual(size.width, DesignTokens.Layout.dashboardPanelWidth, accuracy: 1)
        XCTAssertGreaterThan(size.height, 180)
        XCTAssertLessThan(size.height, 320)

    }

    func testDashboardPlacementUsesTheSpaceBelowTheOverlayWhenAvailable() {
        let origin = DashboardPanelPlacementPolicy.origin(
            panelSize: CGSize(width: 420, height: 260),
            anchorFrame: NSRect(x: 1_698, y: 1_010, width: 222, height: 40),
            visibleFrame: NSRect(x: 0, y: 0, width: 1_920, height: 1_080)
        )

        XCTAssertEqual(origin, NSPoint(x: 1_500, y: 742))
    }

    func testDashboardPlacementMovesAboveTheOverlayWhenBelowWouldOverflow() {
        let origin = DashboardPanelPlacementPolicy.origin(
            panelSize: CGSize(width: 420, height: 260),
            anchorFrame: NSRect(x: 1_698, y: 20, width: 222, height: 40),
            visibleFrame: NSRect(x: 0, y: 0, width: 1_920, height: 1_080)
        )

        XCTAssertEqual(origin, NSPoint(x: 1_500, y: 68))
    }

    func testDashboardPlacementClampsAHeightIncreaseToTheCurrentScreen() {
        let visibleFrame = NSRect(x: -1_920, y: 0, width: 1_920, height: 1_080)
        let origin = DashboardPanelPlacementPolicy.origin(
            panelSize: CGSize(width: 420, height: 900),
            anchorFrame: NSRect(x: -100, y: 100, width: 80, height: 40),
            visibleFrame: visibleFrame
        )

        let frame = NSRect(origin: origin, size: CGSize(width: 420, height: 900))
        XCTAssertTrue(visibleFrame.contains(frame))
    }

    func testDashboardStaysVisibleWhenItsPopoverBecomesKey() {
        XCTAssertFalse(
            DashboardPanelDismissalPolicy.shouldDismiss(
                isExternalPointerEvent: false,
                isInsideDashboard: true
            )
        )
    }

    func testDashboardDismissesForAnExternalPointerEvent() {
        XCTAssertTrue(
            DashboardPanelDismissalPolicy.shouldDismiss(
                isExternalPointerEvent: true,
                isInsideDashboard: false
            )
        )
    }

    func testDashboardKeepsOpenForAnInternalPointerEventReportedGlobally() {
        XCTAssertFalse(
            DashboardPanelDismissalPolicy.shouldDismiss(
                isExternalPointerEvent: true,
                isInsideDashboard: true
            )
        )
    }

    func testDashboardInteractionExcludesUnrelatedApplicationWindows() {
        let dashboard = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.utilityWindow],
            backing: .buffered,
            defer: false
        )
        let detailPopover = NSPanel(
            contentRect: NSRect(x: 210, y: 0, width: 100, height: 100),
            styleMask: [.utilityWindow],
            backing: .buffered,
            defer: false
        )
        let unrelatedWindow = NSPanel(
            contentRect: NSRect(x: 320, y: 0, width: 100, height: 100),
            styleMask: [.utilityWindow],
            backing: .buffered,
            defer: false
        )
        dashboard.addChildWindow(detailPopover, ordered: .above)
        dashboard.orderFront(nil)
        detailPopover.orderFront(nil)
        unrelatedWindow.orderFront(nil)
        defer {
            dashboard.removeChildWindow(detailPopover)
            dashboard.close()
            detailPopover.close()
            unrelatedWindow.close()
        }

        XCTAssertTrue(
            DashboardPanelInteractionPolicy.containsDashboardInteraction(
                at: NSPoint(x: 250, y: 50),
                dashboardPanel: dashboard,
                applicationWindows: [dashboard, detailPopover, unrelatedWindow]
            )
        )
        XCTAssertFalse(
            DashboardPanelInteractionPolicy.containsDashboardInteraction(
                at: NSPoint(x: 350, y: 50),
                dashboardPanel: dashboard,
                applicationWindows: [dashboard, detailPopover, unrelatedWindow]
            )
        )
    }

    func testDashboardPanelBehaviorAvoidsConflictingSpacePolicies() {
        let behavior = DashboardPanelCollectionBehaviorPolicy.behavior

        XCTAssertTrue(behavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(behavior.contains(.fullScreenAuxiliary))
        XCTAssertFalse(behavior.contains(.moveToActiveSpace))
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

    func testAIHistoryChartRendersMultipleProviderSeries() {
        let now = Date()
        let history = NSHostingView(
            rootView: AIUsageTrendChart(
                series: [
                    AIUsageHistorySeries(
                        provider: .codex,
                        points: [
                            UsageHistoryPoint(timestamp: now.addingTimeInterval(-600), remainingPercentage: 85),
                            UsageHistoryPoint(timestamp: now, remainingPercentage: 70),
                        ]
                    ),
                    AIUsageHistorySeries(
                        provider: .claudeCode,
                        points: [
                            UsageHistoryPoint(timestamp: now.addingTimeInterval(-600), remainingPercentage: 60),
                            UsageHistoryPoint(timestamp: now, remainingPercentage: 75),
                        ]
                    ),
                ]
            )
            .frame(width: 320)
        )

        XCTAssertGreaterThan(history.fittingSize.height, 55)
    }

    func testOnboardingFitsItsWindow() {
        let view = OnboardingView(
            settings: AppSettings(),
            multiService: MultiProviderUsageService(),
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
