// swift-tools-version: 5.9
import PackageDescription
import Foundation

let ffmpegKitURL = ProcessInfo.processInfo.environment["FFMPEG_KIT_BINARY_URL"]
let ffmpegKitChecksum = ProcessInfo.processInfo.environment["FFMPEG_KIT_CHECKSUM"]

var playerDependencies: [Target.Dependency] = ["Core", "Common"]
var targets: [Target] = [
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
        name: "Networking",
        dependencies: ["Common"],
        path: "Sources/Networking"
    )
]

if let ffmpegKitURL, let ffmpegKitChecksum {
    targets.append(
        .binaryTarget(
            name: "FFmpegKit",
            url: ffmpegKitURL,
            checksum: ffmpegKitChecksum
        )
    )
    playerDependencies.append("FFmpegKit")
}

targets.append(
    .target(
        name: "Player",
        dependencies: playerDependencies,
        path: "Sources/Features/Player"
    )
)

let package = Package(
    name: "NewPlayer",
    platforms: [
        .iOS(.v16),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "NewPlayer",
            targets: ["Core", "Player", "Library", "Networking", "Common"]
        )
    ],
    dependencies: [
    ],
    targets: targets
)
