// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "MathTutorMac",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "MathTutorMac", targets: ["MathTutorApp"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MathTutorCore",
            path: "Sources/MathTutorCore"
        ),
        .executableTarget(
            name: "MathTutorApp",
            dependencies: ["MathTutorCore"],
            path: "Sources/MathTutorApp"
        ),
        .testTarget(
            name: "MathTutorCoreTests",
            dependencies: ["MathTutorCore"],
            path: "Tests/MathTutorCoreTests"
        )
    ]
)
