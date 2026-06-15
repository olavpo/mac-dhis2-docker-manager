// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "D2Manager",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "D2Manager",
            path: "Sources/D2Manager"
        ),
        .testTarget(
            name: "D2ManagerTests",
            dependencies: ["D2Manager"],
            path: "Tests/D2ManagerTests"
        ),
    ]
)
