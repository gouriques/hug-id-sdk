// swift-tools-version: 5.9
// Pacote na raiz para o Swift Package Manager resolver ao clonar o repositório.
// O código do SDK iOS está em ios/Sources/HUGIdentitySDK.
// A pasta android/ existe no repo (monorepo) mas não é incluída neste target; o SPM clona o repo inteiro, por isso ela aparece no Xcode.

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
