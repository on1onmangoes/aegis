// swift-tools-version:5.9
// Aegis - Cerebras x Gemma 4 Hackathon 260629
// macOS SwiftUI app: provider ID badge -> verified credential graph (Multiverse Agents, Track 1)
import PackageDescription

let package = Package(
    name: "Aegis",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Aegis",
            path: "Sources/Aegis",
            resources: [.copy("Resources/examples")]
        )
    ]
)
