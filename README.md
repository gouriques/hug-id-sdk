# HUG Identity SDK (repositório unificado)

Repositório de **distribuição** dos SDKs de verificação de identidade do **HUG-Identity Service** para iOS e Android. O código-fonte dos SDKs é desenvolvido nos repositórios **HUG-ID-IOS** e **HUG-ID-ANDROID**; os pipelines (Azure DevOps) sincronizam automaticamente para as pastas `ios/` e `android/` deste repositório.

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

Os SDKs consomem a API do **HUG-Identity Service** (session, photo, confirm, status). Documentação e especificação das fases em: [HUG-IdentityService/spec](https://github.com/gouriques/HUG-IdentityService/tree/main/spec).

## Build

- **iOS:** `cd ios && swift build` ou abrir o pacote no Xcode. Ver [ios/DISTRIBUTION.md](ios/DISTRIBUTION.md) para XCFramework.
- **Android:** `cd android && ./gradlew assembleDebug` (ou pelo Android Studio).

## Sincronização a partir dos repositórios de origem

A publicação neste repositório é feita automaticamente pelos pipelines dos projetos **HUG-ID-IOS** e **HUG-ID-ANDROID** no Azure DevOps (push em `main`/`master`). Para publicação manual, use os scripts nos repositórios de origem: [HUG-ID-IOS/doc/PUBLICAR_SDK_NO_GIT.md](https://github.com/gouriques/HUG-ID-IOS/blob/master/doc/PUBLICAR_SDK_NO_GIT.md) e equivalente no Android.
