# HUG Identity SDK (repositório unificado)

Repositório de **distribuição** dos SDKs de verificação de identidade do **HUG-Identity Service** para iOS e Android. O código-fonte principal é desenvolvido nos repositórios **HUG-ID-IOS** e **HUG-ID-ANDROID**; este repo mantém a cópia consumida pelos apps em `ios/` e `android/`, além de binários opcionais quando a distribuição fechada for adotada.

## Estrutura

- **`ios/`** – Pacote Swift (HUGIdentitySDK) para iOS. Ver [ios/README.md](ios/README.md).
- **`android/`** – Módulo Android (Kotlin) para o fluxo de verificação. Ver [android/README.md](android/README.md).
- **`Package.swift`** (raiz) – Swift Package Manager aponta para `ios/` para consumo no Xcode.

## Consumo

### iOS (Swift Package Manager)

No Xcode: **File → Add Package Dependencies** e use a URL deste repositório, por exemplo:

```
https://github.com/gouriques/hug-id-sdk
```

Branch: `master` (ou uma tag, ex.: `1.0.0`). O SPM usa o `Package.swift` na raiz, que referencia o conteúdo em `ios/`.

**Por que a pasta `android/` aparece no pacote no Xcode?** Este repositório é um **monorepo** (iOS + Android). O Swift Package Manager clona o repositório inteiro, então no navegador de pacotes você vê também a pasta `android/`. Apenas o código em `ios/Sources/HUGIdentitySDK` é compilado e usado pelo app; a pasta `android/` não faz parte do produto Swift e pode ser ignorada no Xcode.

### Android

- **Módulo local:** Inclua a pasta `android/` como subprojeto no seu app (ex.: `include ':hug-identity-sdk'` com `projectDir` apontando para `hug-id-sdk/android`).
- **Publicação Maven (futuro):** Quando houver AAR publicado, use as coordenadas no `build.gradle`.

Detalhes de instalação e uso em [android/README.md](android/README.md).

## Backend

Os SDKs consomem a API do **HUG-Identity Service** (`session`, `photo`, `send-code`, `confirm`, `status`) com escolha de canal OTP (e-mail/SMS/WhatsApp, purpose 3). Spec: [HUG-IdentityService/spec](https://github.com/gouriques/HUG-IdentityService/tree/main/spec).

## Build

- **iOS:** `xcodebuild -scheme HUGIdentitySDK -destination 'generic/platform=iOS Simulator' build` ou abrir o pacote no Xcode. Ver [ios/DISTRIBUTION.md](ios/DISTRIBUTION.md) para XCFramework.
- **Android:** abrir `android/` no Android Studio ou usar Gradle/Gradle Wrapper disponível (`gradle assembleDebug` ou `./gradlew assembleDebug`).

## Publicação

Para sincronizar os repositórios de origem e validar antes do commit:

```bash
./scripts/sync_from_source_repos.sh
xcodebuild -scheme HUGIdentitySDK -destination 'generic/platform=iOS Simulator' build
# Android: valide pelo Android Studio ou rode gradle assembleDebug/./gradlew assembleDebug se disponível.
```

Detalhes do procedimento manual e dos artefatos binários opcionais estão em [docs/PUBLICACAO_SDKS.md](docs/PUBLICACAO_SDKS.md).

## Sincronização a partir dos repositórios de origem

A publicação neste repositório pode ser feita pelos pipelines dos projetos **HUG-ID-IOS** e **HUG-ID-ANDROID** no Azure DevOps (push em `main`/`master`) ou manualmente com os scripts locais. Para publicação manual, use [docs/PUBLICACAO_SDKS.md](docs/PUBLICACAO_SDKS.md) e os documentos dos repositórios de origem: [HUG-ID-IOS/docs/PUBLICAR_SDK_NO_GIT.md](https://github.com/gouriques/HUG-ID-IOS/blob/master/docs/PUBLICAR_SDK_NO_GIT.md) e [HUG-ID-ANDROID/docs/PUBLICAR_SDK_NO_GIT.md](https://github.com/gouriques/HUG-ID-ANDROID/blob/master/docs/PUBLICAR_SDK_NO_GIT.md).
