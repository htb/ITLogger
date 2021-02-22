// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "ITLogger",
    products: [
        .library(name: "ITLogger", targets: ["ITLogger"]),
    ],
    dependencies: [
        //.package(path: "../ITMulticastDelegate")
        .package(url: "git@github.com:htb/ITMulticastDelegate.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "ITLogger", dependencies: ["ITMulticastDelegate"]),
        .testTarget(name: "ITLoggerTests", dependencies: ["ITLogger"]),
    ]
)
