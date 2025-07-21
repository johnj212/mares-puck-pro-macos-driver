// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MaresPuckProDriver",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MaresPuckProDriver",
            targets: ["MaresPuckProDriver"]),
        .executable(
            name: "MaresPuckProDriverApp",
            targets: ["MaresPuckProDriverApp"]),
    ],
    dependencies: [
        // We'll add ORSSerialPort as a dependency
        .package(url: "https://github.com/armadsen/ORSSerialPort.git", from: "2.1.0"),
    ],
    targets: [
        .target(
            name: "MaresPuckProDriver",
            dependencies: [
                .product(name: "ORSSerial", package: "ORSSerialPort")
            ],
            path: "Sources/MaresPuckProDriver"),
        .executableTarget(
            name: "MaresPuckProDriverApp",
            dependencies: ["MaresPuckProDriver"],
            path: "Sources/MaresPuckProDriverApp"),
        .testTarget(
            name: "MaresPuckProDriverTests",
            dependencies: ["MaresPuckProDriver"],
            path: "Tests/MaresPuckProDriverTests"),
    ]
)