// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DrawThingsStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "StoryFlow", targets: ["StoryFlow"]),
    ],
    dependencies: [
        // No external dependencies needed for the current logic files
        // (gRPC dependencies are for the gRPC module which is not yet implemented)
    ],
    targets: [
        .target(
            name: "Core",
            path: "Sources/Core"
        ),
        .target(
            name: "StoryFlow",
            dependencies: [], // Currently independent
            path: "Sources/StoryFlow"
        )
    ]
)
