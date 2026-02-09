#!/usr/bin/env bash
# Copia o código do HUG-ID-IOS para a pasta ios/ do repositório hug-id-sdk.
# Uso: ./Scripts/publish_to_sdk_repo.sh
# Variável de ambiente: SDK_REPO_PATH (default: ../hug-id-sdk em relação à raiz do HUG-ID-IOS)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SDK_REPO="${SDK_REPO_PATH:-$REPO_ROOT/../hug-id-sdk}"
IOS_DEST="$SDK_REPO/ios"

if [ ! -d "$SDK_REPO" ]; then
  echo "Erro: repositório hug-id-sdk não encontrado em: $SDK_REPO"
  echo "Defina SDK_REPO_PATH ou clone o repo ao lado de HUG-ID-IOS."
  exit 1
fi

echo "Origem: $REPO_ROOT"
echo "Destino: $IOS_DEST"
echo ""

# Copiar Sources
rm -rf "$IOS_DEST/Sources"
mkdir -p "$IOS_DEST/Sources"
cp -R "$REPO_ROOT/Sources/HUGIdentitySDK" "$IOS_DEST/Sources/"

# Copiar Package.swift, README, etc.
for f in Package.swift README.md DISTRIBUTION.md Package.binary.example.swift; do
  if [ -f "$REPO_ROOT/$f" ]; then
    cp "$REPO_ROOT/$f" "$IOS_DEST/"
  fi
done

# Copiar Scripts
rm -rf "$IOS_DEST/Scripts"
mkdir -p "$IOS_DEST/Scripts"
if [ -d "$REPO_ROOT/Scripts" ]; then
  cp -R "$REPO_ROOT/Scripts/"* "$IOS_DEST/Scripts/"
fi

echo "Concluído: conteúdo iOS copiado para $IOS_DEST"
echo "Próximo passo: no hug-id-sdk, faça git add ios/ && git commit && git push"
