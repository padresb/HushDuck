// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HushDuck",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "HushDuck",
            path: "Sources/HushDuck",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("ApplicationServices"),
            ]
        )
    ]
)
