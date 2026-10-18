// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "MacAppLauncher",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "MacAppLauncher", path: "Sources/MacAppLauncher",
                          swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
