# Publicação dos SDKs no hug-id-sdk

Este repositório é o ponto de distribuição dos SDKs HUG-ID. Os repositórios de origem continuam sendo:

- iOS: [`HUG-ID-IOS`](/Users/guilherme/sourcecode/HUG-ID-IOS)
- Android: [`HUG-ID-ANDROID`](/Users/guilherme/sourcecode/HUG-ID-ANDROID)

## Fluxo recomendado

1. Implemente e valide a alteração no repositório de origem.
2. Sincronize para este repositório:

```bash
cd /Users/guilherme/sourcecode/hug-id-sdk
./scripts/sync_from_source_repos.sh
```

Se os repositórios não estiverem ao lado do `hug-id-sdk`, use:

```bash
HUG_ID_IOS_REPO_PATH=/caminho/HUG-ID-IOS \
HUG_ID_ANDROID_REPO_PATH=/caminho/HUG-ID-ANDROID \
./scripts/sync_from_source_repos.sh
```

3. Valide os builds distribuídos:

```bash
# iOS por fonte SwiftPM
xcodebuild -scheme HUGIdentitySDK -destination 'generic/platform=iOS Simulator' build

# Android por fonte Gradle
cd android
# Valide pelo Android Studio ou use Gradle/Gradle Wrapper se disponível:
# gradle assembleDebug
# ./gradlew assembleDebug
cd ..
```

O SDK Android não versiona Gradle Wrapper próprio atualmente. Se o ambiente não tiver `gradle` instalado, valide abrindo `android/` no Android Studio ou usando o wrapper do projeto consumidor.

4. Publique somente fontes, documentação, scripts e artefatos binários deliberados:

```bash
git add Package.swift README.md docs/ ios/ android/ scripts/ .gitignore
git status
git commit -m "sync: atualiza SDKs HUG-ID"
git push origin master
```

## iOS binário opcional

O consumo atual do HUGDoctor-iOS usa Swift Package Manager por fonte, via `Package.swift` da raiz, que aponta para `ios/Sources/HUGIdentitySDK`.

Se for necessário publicar um SDK iOS fechado/binário:

```bash
cd ios
./Scripts/build_xcframework.sh
cd build
rm -f HUGIdentitySDK.xcframework.zip
zip -r HUGIdentitySDK.xcframework.zip HUGIdentitySDK.xcframework
swift package compute-checksum HUGIdentitySDK.xcframework.zip
```

Publique o `HUGIdentitySDK.xcframework.zip` em GitHub Releases/CDN e use `ios/Package.binary.example.swift` como base do pacote wrapper com `binaryTarget`.

## O que não publicar

Não publique caches e intermediários de build:

- `.build/`
- `.gradle/`
- `android/build/`
- `ios/build/*.xcarchive`
- `ios/build/DerivedData*`
- `ios/ios/`

Esses caminhos são ignorados no `.gitignore`. O `ios/build/HUGIdentitySDK.xcframework.zip` pode ser mantido quando a publicação binária for intencional.
