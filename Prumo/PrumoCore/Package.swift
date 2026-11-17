// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PrumoCore",
    defaultLocalization: "pt-BR",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PrumoCore", targets: ["PrumoCore"]),
    ],
    targets: [
        .target(name: "PrumoCore"),
        .testTarget(
            name: "PrumoCoreTests",
            dependencies: ["PrumoCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
