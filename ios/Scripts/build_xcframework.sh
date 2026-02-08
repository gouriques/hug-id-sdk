#!/usr/bin/env bash
# Gera HUGIdentitySDK.xcframework para distribuição (SDK fechado).
# Uso: ./Scripts/build_xcframework.sh
# Saída: build/HUGIdentitySDK.xcframework (e .zip opcional)
# Nota: na primeira vez, abra o pacote no Xcode (abrir a pasta HUG-ID-IOS) para que o scheme HUGIdentitySDK exista.

set -e
cd "$(dirname "$0")/.."
PKG_NAME=HUGIdentitySDK
BUILD_DIR=build
ARCHIVE_IOS=$BUILD_DIR/${PKG_NAME}-iOS.xcarchive
ARCHIVE_SIM=$BUILD_DIR/${PKG_NAME}-Sim.xcarchive
XCFRAMEWORK=$BUILD_DIR/${PKG_NAME}.xcframework

echo "Building $PKG_NAME for iOS (device)..."
xcodebuild archive \
  -scheme "$PKG_NAME" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_IOS" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

echo "Building $PKG_NAME for iOS Simulator..."
xcodebuild archive \
  -scheme "$PKG_NAME" \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "$ARCHIVE_SIM" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

echo "Creating XCFramework..."
rm -rf "$XCFRAMEWORK"
xcodebuild -create-xcframework \
  -framework "$ARCHIVE_IOS/Products/Library/Frameworks/${PKG_NAME}.framework" \
  -framework "$ARCHIVE_SIM/Products/Library/Frameworks/${PKG_NAME}.framework" \
  -output "$XCFRAMEWORK"

echo "Done: $XCFRAMEWORK"
echo "To zip for distribution: cd build && zip -r HUGIdentitySDK.xcframework.zip HUGIdentitySDK.xcframework"
