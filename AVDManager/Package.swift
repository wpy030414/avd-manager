// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AVDManager",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "AVDManager",
            targets: ["AVDManager"]
        ),
        .executable(
            name: "DebugEmulator",
            targets: ["DebugEmulator"]
        ),
    ],
    targets: [
        // SwiftUI property-wrapper / preview macros require a library target,
        // then a thin executable wrapper links it.
        .target(
            name: "AVDManagerKit",
            path: "Sources/AVDManagerKit",
            resources: [
                .process("../../Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "AVDManager",
            dependencies: ["AVDManagerKit"],
            path: "Sources/AVDManagerCLI",
            exclude: ["Debug/"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .debug))
            ]
        ),
        .executableTarget(
            name: "DebugEmulator",
            dependencies: ["AVDManagerKit"],
            path: "Sources/AVDManagerCLI/Debug",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ]
)
