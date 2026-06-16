// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AudioRecordTool",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "AudioRecordTool", targets: ["AudioRecordTool"])
    ],
    targets: [
        .target(name: "AudioRecordTool", dependencies: [], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "AudioRecordToolTests", dependencies: ["AudioRecordTool"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)

