# hug-id-sdk — Distribuição dos SDKs HUG-ID

Repositório que **distribui os SDKs HUG-ID** (iOS e Android). Os apps HUGDoctor-iOS e HUGDoctor-Android, e clientes externos, consomem este repositório como dependência via Git.

> Este repositório contém a **cópia distribuída** do código-fonte em `ios/` e `android/`, além de binários opcionais quando a distribuição fechada for adotada. O código-fonte principal mora em [HUG-ID-IOS](/Users/guilherme/sourcecode/HUG-ID-IOS) e [HUG-ID-ANDROID](/Users/guilherme/sourcecode/HUG-ID-ANDROID); o backend está em [HUG-IdentityService](/Users/guilherme/sourcecode/HUG-IdentityService).

## Documentos

- [`../README.md`](../README.md) — README principal do repositório (aponta para iOS e Android).
- [`../ios/README.md`](../ios/README.md) — guia de consumo do SDK iOS via Swift Package Manager.
- [`../ios/DISTRIBUTION.md`](../ios/DISTRIBUTION.md) — detalhes de distribuição do binário iOS.
- [`../android/README.md`](../android/README.md) — guia de consumo do SDK Android.
- [`PUBLICACAO_SDKS.md`](PUBLICACAO_SDKS.md) — procedimento manual de sincronização, validação e publicação.

## Onde está cada coisa

| Componente | Repositório |
|------------|-------------|
| Código-fonte iOS | [HUG-ID-IOS](/Users/guilherme/sourcecode/HUG-ID-IOS) |
| Código-fonte Android | [HUG-ID-ANDROID](/Users/guilherme/sourcecode/HUG-ID-ANDROID) |
| Backend (.NET 8) | [HUG-IdentityService](/Users/guilherme/sourcecode/HUG-IdentityService) |
| Documentação do ecossistema | [HUGDoctor/docs/README.md](/Users/guilherme/sourcecode/HUGDoctor/docs/README.md) |
