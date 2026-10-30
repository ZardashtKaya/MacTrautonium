// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacTrautonium",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacTrautonium", targets: ["MacTrautonium"]),
        .library(name: "TrautoniumKit", targets: ["TrautoniumKit"])
    ],
    targets: [
        .target(
            name: "TrautoniumKit",
            dependencies: [],
            path: "Sources/TrautoniumKit"
        ),
        .executableTarget(
            name: "MacTrautonium",
            dependencies: ["TrautoniumKit"],
            path: "Sources/MacTrautonium"
        ),
        .testTarget(
            name: "MacTrautoniumTests",
            dependencies: ["TrautoniumKit"],
            path: "Tests/MacTrautoniumTests"
        )
    ]
)
