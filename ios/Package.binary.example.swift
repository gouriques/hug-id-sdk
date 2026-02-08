// swift-tools-version: 5.9
// Use este Package.swift quando distribuir apenas o XCFramework (SDK fechado).
// 1. Gere o XCFramework: ./Scripts/build_xcframework.sh
// 2. Compacte: cd build && zip -r HUGIdentitySDK.xcframework.zip HUGIdentitySDK.xcframework
// 3. Publique o .zip numa URL (GitHub Release, CDN, etc.)
// 4. Substitua a URL abaixo pela URL do .zip e renomeie este arquivo para Package.swift (ou use um repo só para o wrapper).

import PackageDescription

let package = Package(
    name: "HUGIdentitySDK",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "HUGIdentitySDK", targets: ["HUGIdentitySDK"]),
    ],
    targets: [
        .binaryTarget(
            name: "HUGIdentitySDK",
            url: "https://github.com/SEU_ORG/HUG-ID-IOS/releases/download/1.0.0/HUGIdentitySDK.xcframework.zip",
            checksum: "REPLACE_WITH_SWIFT_PACKAGE_COMPUTED_CHECKSUM"
        ),
    ]
)
