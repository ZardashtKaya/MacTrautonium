// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacTrautonium",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacTrautonium", targets: ["MacTrautonium"]),
        .library(name: "TrautoniumKit", targets: ["TrautoniumKit"]),
        .library(name: "MacTrautoniumLib", targets: ["MacTrautoniumLib"])
    ],
    targets: [
        .target(
            name: "TrautoniumKit",
            dependencies: [],
            path: "Sources/TrautoniumKit"
        ),
        .target(
            name: "MacTrautoniumLib",
            dependencies: ["TrautoniumKit"],
            path: "Sources/MacTrautonium"
        ),
        .executableTarget(
            name: "MacTrautonium",
            dependencies: ["MacTrautoniumLib", "TrautoniumKit"],
            path: "Sources/MacTrautoniumApp"
        ),
        .testTarget(
            name: "MacTrautoniumTests",
            dependencies: ["TrautoniumKit", "MacTrautoniumLib"],
            path: "Tests/MacTrautoniumTests"
        )
    ]
)
