// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Amarillo",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Amarillo",
            path: "Sources/Amarillo"
        ),
        .testTarget(
            name: "AmarilloTests",
            dependencies: ["Amarillo"],
            path: "Tests/AmarilloTests"
        ),
    ]
)
