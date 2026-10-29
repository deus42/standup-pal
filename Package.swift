// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StandUpPal",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "StandUpPal",
            path: "Sources/StandUpPal",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreMediaIO"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "StandUpPalTests",
            dependencies: ["StandUpPal"],
            path: "Tests/StandUpPalTests"
        ),
    ]
)
