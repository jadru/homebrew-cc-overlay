import Foundation
import XCTest

final class ReleaseMetadataTests: XCTestCase {
    func testInfoPlistDeclaresLaunchableAppBundle() throws {
        let infoURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/CCOverlay/Info.plist")
        let data = try Data(contentsOf: infoURL)
        let plist = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "cc-overlay")
        XCTAssertEqual(plist["CFBundlePackageType"] as? String, "APPL")
    }
}
