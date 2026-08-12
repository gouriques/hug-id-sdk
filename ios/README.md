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
https://github.com/gouriques/hug-id-sdk
```

Ou no `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/gouriques/hug-id-sdk", from: "1.0.0"),
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

- `POST /v1/verification/session` – cria sessão. Retorna `availableChannels[]` (sms/email/whatsapp com rota ativa).
- `POST /v1/verification/photo` – envia selfie; **não** envia OTP (status → `pending_send`).
- `POST /v1/verification/send-code` – envia OTP no `channel` escolhido (purpose **OTP 3**).
- `POST /v1/verification/confirm` – confirma código.
- `GET /v1/verification/status` – status (`pending_photo` | `pending_send` | `pending_code` | `verified` | `expired`).

Fluxo UI: selfie → cards de canal → Enviar código → digitar OTP (reenvio com cooldown 60s).

## Build

```bash
# No repositório de origem:
cd HUG-ID-IOS
xcodebuild -scheme HUGIdentitySDK -destination 'generic/platform=iOS Simulator' build

# No repositório de distribuição:
cd hug-id-sdk
xcodebuild -scheme HUGIdentitySDK -destination 'generic/platform=iOS Simulator' build
```

Como o SDK usa UIKit, valide com `xcodebuild` para iOS (device/simulator) ou pelo Xcode. `swift build` puro usa o destino macOS por padrão e não é a validação correta para este pacote.

Para publicar no repositório consumido pelos apps, use `docs/PUBLICAR_SDK_NO_GIT.md` no `HUG-ID-IOS` ou `docs/PUBLICACAO_SDKS.md` no `hug-id-sdk`.
