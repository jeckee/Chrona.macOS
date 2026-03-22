// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Chrona",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Chrona", targets: ["Chrona"]),
        .executable(name: "ChronaCLI", targets: ["ChronaRunner"])
    ],
    targets: [
        .target(name: "Chrona"),
        .executableTarget(
            name: "ChronaRunner",
            dependencies: ["Chrona"]
        )
    ]
)
