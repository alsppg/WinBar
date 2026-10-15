// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WinBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WinBar",
            path: "Sources/WinBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
