// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Bluejay",
    platforms: [
        .iOS(.v11),
    ],
    products: [
        .library(
            name: "Bluejay",
            targets: ["Bluejay"]),
    ],
    dependencies: [
        .package(url: "https://github.com/DaveWoodCom/XCGLogger", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "Bluejay",
            dependencies: ["XCGLogger"],
            path: "Bluejay/Bluejay"),
    ],
    swiftLanguageVersions: [.v5]
)
