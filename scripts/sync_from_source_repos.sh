#!/usr/bin/env bash
# Sincroniza os SDKs iOS e Android a partir dos repositórios de origem.
# Variáveis:
#   HUG_ID_IOS_REPO_PATH      default: ../HUG-ID-IOS
#   HUG_ID_ANDROID_REPO_PATH  default: ../HUG-ID-ANDROID

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
IOS_REPO="${HUG_ID_IOS_REPO_PATH:-$SDK_REPO/../HUG-ID-IOS}"
ANDROID_REPO="${HUG_ID_ANDROID_REPO_PATH:-$SDK_REPO/../HUG-ID-ANDROID}"

require_dir() {
  local path="$1"
  local label="$2"

  if [ ! -d "$path" ]; then
    echo "Erro: $label não encontrado em: $path"
    echo "Defina a variável de ambiente correspondente ou clone o repo ao lado do hug-id-sdk."
    exit 1
  fi
}

copy_if_exists() {
  local source_file="$1"
  local dest_dir="$2"

  if [ -f "$source_file" ]; then
    cp "$source_file" "$dest_dir/"
  fi
}

require_dir "$IOS_REPO" "HUG-ID-IOS"
require_dir "$ANDROID_REPO" "HUG-ID-ANDROID"

echo "Sincronizando iOS..."
rm -rf "$SDK_REPO/ios/Sources"
mkdir -p "$SDK_REPO/ios/Sources"
cp -R "$IOS_REPO/Sources/HUGIdentitySDK" "$SDK_REPO/ios/Sources/"
for file in Package.swift README.md DISTRIBUTION.md Package.binary.example.swift; do
  copy_if_exists "$IOS_REPO/$file" "$SDK_REPO/ios"
done
rm -rf "$SDK_REPO/ios/Scripts"
mkdir -p "$SDK_REPO/ios/Scripts"
if [ -d "$IOS_REPO/Scripts" ]; then
  cp -R "$IOS_REPO/Scripts/"* "$SDK_REPO/ios/Scripts/"
fi

echo "Sincronizando Android..."
for file in build.gradle gradle.properties proguard-rules.pro settings.gradle README.md; do
  copy_if_exists "$ANDROID_REPO/$file" "$SDK_REPO/android"
done
rm -rf "$SDK_REPO/android/src"
cp -R "$ANDROID_REPO/src" "$SDK_REPO/android/"

echo "Sincronização concluída."
echo "Valide os builds e publique apenas fontes/documentação e artefatos intencionais."
