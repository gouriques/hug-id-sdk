# Distribuição do HUGIdentitySDK

## Opção A: Repositório Git (código-fonte) – fluxo atual

O app depende do SDK via Swift Package Manager apontando para o repositório de distribuição `hug-id-sdk`:

1. Publique as alterações deste repo no `hug-id-sdk` seguindo `docs/PUBLICAR_SDK_NO_GIT.md`.
2. **No app** (ex.: DeviceBinding ou HugSaude), adicione a dependência por URL:
   - Por **versão**: `.package(url: "https://github.com/gouriques/hug-id-sdk.git", from: "1.0.0")`  
     Ao publicar uma nova tag (ex.: `1.0.1`), o Xcode pode resolver atualizações (ex.: `.upToNextMinor(from: "1.0.0")`).
   - Por **branch**: `.package(url: "https://github.com/gouriques/hug-id-sdk.git", branch: "master")`  
     O Xcode baixa a branch ao resolver dependências.
3. **Tags**: crie tags (ex.: `1.0.0`, `1.0.1`) para versões estáveis. O app usa `from: "1.0.0"` ou `exact: "1.0.0"`.

## Opção B: SDK binário (XCFramework) – SDK fechado

1. **Gerar o XCFramework** (a partir da raiz do pacote):
   ```bash
   chmod +x Scripts/build_xcframework.sh
   ./Scripts/build_xcframework.sh
   ```
2. **Compactar**: `cd build && zip -r HUGIdentitySDK.xcframework.zip HUGIdentitySDK.xcframework`
3. **Publicar o .zip** numa URL (GitHub Releases, artefato de build, CDN).
4. **Pacote wrapper**: use `Package.binary.example.swift` como base, coloque a URL do .zip e o checksum (obtido com `swift package compute-checksum HUGIdentitySDK.xcframework.zip`). O app dependerá desse pacote (que expõe apenas o `.binaryTarget`).

O `Package.swift` deste repo declara a library como dinâmica para que o archive SwiftPM gere `Products/usr/local/lib/HUGIdentitySDK.framework`, caminho usado por `Scripts/build_xcframework.sh`.

## Resumo

- **Atualizações pelo repositório**: use Opção A com URL do repo e tag ou branch; o Xcode baixa ao resolver pacotes.
- **SDK fechado**: use Opção B e distribua o XCFramework por URL; o app consome o pacote que declara o `.binaryTarget`.
