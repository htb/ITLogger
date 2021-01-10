// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "ITLogger",
    products: [
        .library(name: "ITLogger", targets: ["ITLogger"]),
    ],
    dependencies: [
        .package(url: "../ITMulticastDelegate", from: "0.0.1")
    ],
    targets: [
        .target(name: "ITLogger", dependencies: []),
        .testTarget(name: "ITLoggerTests", dependencies: ["ITLogger"]),
    ]
)
