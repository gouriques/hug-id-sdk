// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HUGIdentitySDK",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "HUGIdentitySDK", targets: ["HUGIdentitySDK"]),
    ],
    targets: [
        .target(
            name: "HUGIdentitySDK",
            path: "Sources/HUGIdentitySDK"
        ),
    ]
)
