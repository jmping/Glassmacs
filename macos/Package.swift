// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GlassmacsLauncher",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GlassmacsLauncherCore", targets: ["GlassmacsLauncherCore"]),
        .executable(name: "GlassmacsLauncher", targets: ["GlassmacsLauncher"])
    ],
    targets: [
        .target(name: "GlassmacsLauncherCore"),
        .executableTarget(
            name: "GlassmacsLauncher",
            dependencies: ["GlassmacsLauncherCore"]
        ),
        .testTarget(
            name: "GlassmacsLauncherCoreTests",
            dependencies: ["GlassmacsLauncherCore"]
        )
    ]
)
