import XCTest
@testable import CCOverlay

final class UsageExportServiceTests: XCTestCase {
    func testCSVExportEscapesUserControlledFields() {
        let entry = ParsedUsageEntry(
            sessionId: "session,1",
            model: "claude\"model",
            inputTokens: 10,
            outputTokens: 20,
            cacheCreationTokens: 30,
            cacheReadTokens: 40,
            timestamp: Date(timeIntervalSince1970: 0),
            projectName: "my, \"project\""
        )

        let csv = UsageExportService.csvExport(entries: [entry])

        XCTAssertTrue(csv.contains("\"session,1\",\"my, \"\"project\"\"\",\"claude\"\"model\""))
    }

    func testCSVExportNeutralizesSpreadsheetFormulas() {
        let entry = ParsedUsageEntry(
            sessionId: "=SUM(1,1)",
            model: "\t@danger",
            inputTokens: 10,
            outputTokens: 20,
            cacheCreationTokens: 30,
            cacheReadTokens: 40,
            timestamp: Date(timeIntervalSince1970: 0),
            projectName: "+formula"
        )

        let csv = UsageExportService.csvExport(entries: [entry])

        XCTAssertTrue(csv.contains("\"'=SUM(1,1)\",\"'+formula\",\"'\t@danger\""))
    }
}
