// swift-tools-version: 5.9
// Pacote na raiz para o Swift Package Manager resolver ao clonar o repositório.
// O código do SDK iOS está em ios/Sources/HUGIdentitySDK.

import PackageDescription

let package = Package(
    name: "HUGIdentitySDK",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "HUGIdentitySDK", targets: ["HUGIdentitySDK"]),
    ],
    targets: [
        .target(
            name: "HUGIdentitySDK",
            path: "ios/Sources/HUGIdentitySDK"
        ),
    ]
)
