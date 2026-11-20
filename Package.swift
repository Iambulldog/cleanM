// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "CleanM",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CleanM", targets: ["CleanM"])
    ],
    targets: [
        .executableTarget(
            name: "CleanM",
            path: "Sources/CleanM",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Quartz"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
