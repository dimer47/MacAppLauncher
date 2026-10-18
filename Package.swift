// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacAppLauncher",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "MacAppLauncher", path: "Sources/MacAppLauncher")
    ]
)
