// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CC-Overlay",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "cc-overlay", targets: ["CCOverlay"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .executableTarget(
            name: "CCOverlay",
            path: "Sources/CCOverlay",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/CCOverlay/Info.plist",
                ]),
            ]
        ),
        .testTarget(
            name: "CCOverlayTests",
            dependencies: [
                "CCOverlay",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/CCOverlayTests"
        ),
    ]
)
