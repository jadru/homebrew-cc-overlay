import XCTest
@testable import CCOverlay

final class DockerStorageServiceTests: XCTestCase {
    func testParsesDockerStorageAndKeepsLargestThreeVolumes() throws {
        let summary = """
        {"Type":"Images","TotalCount":"5","Active":"2","Size":"1.5GB","Reclaimable":"500MB (33%)"}
        {"Type":"Containers","TotalCount":"3","Active":"2","Size":"400MB","Reclaimable":"0B (0%)"}
        {"Type":"Local Volumes","TotalCount":"4","Active":"3","Size":"2.25GB","Reclaimable":"0B (0%)"}
        {"Type":"Build Cache","TotalCount":"7","Active":"1","Size":"3GB","Reclaimable":"2GB"}
        """
        let volumes = """
        [
          {"Name":"small","Size":"128MB","Links":"1"},
          {"Name":"large","Size":"1.5GB","Links":"2"},
          {"Name":"medium","Size":"512MB","Links":"1"},
          {"Name":"zero","Size":"0B","Links":"0"}
        ]
        """

        let snapshot = try XCTUnwrap(
            DockerStorageCollector.makeSnapshot(summaryOutput: summary, volumeOutput: volumes)
        )

        XCTAssertEqual(snapshot.categories.map(\.label), ["Images", "Containers", "Volumes", "Build cache"])
        XCTAssertEqual(snapshot.volumeCount, 4)
        XCTAssertEqual(snapshot.largestVolumes.map(\.name), ["large", "medium", "small"])
        XCTAssertEqual(snapshot.largestVolumes.first?.linkCount, 2)
    }

    func testDockerByteParserSupportsDecimalAndBinaryUnits() {
        XCTAssertEqual(DockerStorageCollector.parseBytes("1.5GB"), 1_500_000_000)
        XCTAssertEqual(DockerStorageCollector.parseBytes("1.5GiB"), 1_610_612_736)
        XCTAssertEqual(DockerStorageCollector.parseBytes("0B"), 0)
        XCTAssertNil(DockerStorageCollector.parseBytes("unknown"))
    }

    func testMalformedDockerOutputIsUnavailable() {
        XCTAssertNil(DockerStorageCollector.makeSnapshot(summaryOutput: "not json", volumeOutput: "[]"))
        XCTAssertEqual(DockerStorageCollector.parseVolumeOutput("not json"), [])
    }
}
