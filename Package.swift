// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NewPlayer",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NewPlayer",
            targets: ["Core", "Player", "Library", "Networking", "Common"]
        )
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Common",
            dependencies: [],
            path: "Sources/Common"
        ),
        .target(
            name: "Core",
            dependencies: ["Common"],
            path: "Sources/Core"
        ),
        .target(
            name: "Library",
            dependencies: ["Core", "Common", "Networking"],
            path: "Sources/Features/Library",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "Player",
            dependencies: ["Core", "Common"],
            path: "Sources/Features/Player"
        ),
        .target(
            name: "Networking",
            dependencies: ["Common"],
            path: "Sources/Networking"
        )
    ]
)
