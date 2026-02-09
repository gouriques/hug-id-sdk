# HUGIdentitySDK (iOS)

SDK de verificação de identidade do **HUG-Identity Service**. Fluxo: criar sessão → captura de foto (selfie) → upload da foto (código enviado por e-mail ou SMS) → digitar código → confirmação. Integrado ao HUGDoctor-iOS (Fase 1 concluída); FaceTec foi descontinuado neste fluxo.

## Requisitos

- iOS 14+
- Xcode 14+ / Swift 5.9

## Distribuição

- **Por repositório (código-fonte)**: o app adiciona o pacote pela URL do repositório (branch ou tag). Ver [DISTRIBUTION.md](DISTRIBUTION.md).
- **Por binário (XCFramework)**: execute `./Scripts/build_xcframework.sh`, publique o `.xcframework.zip` e use um pacote com `.binaryTarget`. Ver [DISTRIBUTION.md](DISTRIBUTION.md) e `Package.binary.example.swift`.

Para publicar uma versão, crie uma tag no repositório (ex.: `git tag 1.0.0 && git push origin 1.0.0`).

## Instalação

### Swift Package Manager

Adicione ao seu projeto (Xcode: File → Add Package Dependencies) a URL do repositório, por exemplo:

```
https://github.com/SEU_ORG/HUG-ID-IOS
```

Ou no `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<org>/HUG-ID-IOS", from: "1.0.0"),
],
targets: [
    .target(name: "SeuApp", dependencies: ["HUGIdentitySDK"]),
]
```

## Uso

1. Configure com a URL base da API, token (opcional) e dados do usuário (userId, email, phone).
2. Chame `IdentityService.startVerification(from:config:completion:)` a partir do view controller atual.
3. O SDK apresenta o fluxo em modal (sessão → foto → código). No final, o `completion` é chamado com `.success`, `.cancelled` ou `.failure(Error)`.

```swift
import HUGIdentitySDK

let config = IdentityServiceConfig(
    baseURL: "https://hugsaudeapigateway.azure-api.net/hug-identity",
    authorizationToken: "Bearer \(seuToken)",  // opcional
    userId: "123",
    email: "usuario@email.com",
    phone: "+5511999999999"
)

IdentityService.startVerification(from: self, config: config) { result in
    switch result {
    case .success:
        // Verificação concluída; seguir para próxima tela
    case .cancelled:
        // Usuário cancelou
    case .failure(let error):
        // Exibir error.localizedDescription
    }
}
```

## API pública

- **IdentityServiceConfig** – baseURL, authorizationToken?, userId, email, phone
- **VerificationResult** – .success | .cancelled | .failure(Error)
- **IdentityServiceError** – erros do SDK (invalidURL, apiError, photoRejected, codeInvalid, etc.)
- **IdentityService.startVerification(from:config:completion:)** – inicia o fluxo

## Contrato do backend

O SDK consome a API do HUG-Identity Service:

- `POST /v1/verification/session` – cria sessão (body: userId, email, phone). Retorna `verificationSessionId`, `expiresAt`, `maskedEmail`, `maskedPhone`.
- `POST /v1/verification/photo` – envia foto (multipart: verificationSessionId, file). Retorna `accepted`, `maskedDestination` (destino mascarado onde o código foi enviado: e-mail ou SMS).
- `POST /v1/verification/confirm` – confirma código (body: verificationSessionId, code).
- `GET /v1/verification/status?verificationSessionId=...` – opcional; retorna status da sessão (`pending_photo`, `pending_code`, `verified`, `expired`).

O código é enviado por **um único canal** por solicitação: prioridade e-mail; SMS apenas se não houver e-mail ou se o envio por e-mail falhar. A tela de código exibe apenas o destino efetivo (`maskedDestination`).

## Build

```bash
cd HUG-ID-IOS
swift build
```

Para compilar para iOS (device/simulator), use Xcode abrindo a pasta do pacote ou adicione o pacote como dependência em um app e faça o build pelo Xcode.
