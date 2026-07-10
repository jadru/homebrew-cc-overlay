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

    func testEmptyPanelRendersMessageAndRecoveryActions() {
        let view = MenuBarView(
            multiService: MultiProviderUsageService(),
            settings: AppSettings(),
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
