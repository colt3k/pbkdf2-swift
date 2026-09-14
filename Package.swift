// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "pbkdf2-swift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PBKDF2Swift",
            targets: ["PBKDF2Swift"]
        )
    ],
    targets: [
        .target(name: "PBKDF2Swift"),
        .testTarget(
            name: "PBKDF2SwiftTests",
            dependencies: ["PBKDF2Swift"]
        )
    ]
)