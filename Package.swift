// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MicrophoneStream",
    defaultLocalization: "en",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(name: "MicrophoneStream", targets: ["MicrophoneStream"])
    ],
    dependencies: [
        .package(url: "https://github.com/UnpxreTW/SwiftStyleKit.git", from: "2.0.1"),
    ],
    targets: [
        .target(name: "MicrophoneStream", dependencies: [], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "MicrophoneStreamTests", dependencies: ["MicrophoneStream"], swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
