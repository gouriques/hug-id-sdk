# HUG Identity SDK (Android)

SDK de verificação de identidade do **HUG-Identity Service**. Fluxo: criar sessão → captura de foto (selfie) → upload da foto (código enviado por e-mail ou SMS) → digitar código → confirmação. Pronto para integração no HUGDoctor-Android; repositório unificado de distribuição: **hug-id-sdk** (pasta `android/`).

## Requisitos

- Android minSdk 21
- Kotlin 1.8+
- AndroidX

## Instalação

### Gradle (repositório local ou Maven)

Inclua o módulo no `settings.gradle` (se estiver no mesmo repositório):

```gradle
include ':hug-identity-sdk'
project(':hug-identity-sdk').projectDir = new File('../HUG-ID-ANDROID')
```

No `build.gradle` do app:

```gradle
dependencies {
    implementation project(':hug-identity-sdk')
}
```

Ou publique o AAR em um repositório Maven e use:

```gradle
implementation 'com.hug.identity:sdk:1.0.0'
```

## Uso

1. Configure com a URL base da API, token (opcional) e dados do usuário (userId, email, phone).
2. Chame `IdentityService.startVerification(activity, config, requestCode)` a partir da Activity.
3. Em `onActivityResult`, use `IdentityService.parseResult(resultCode, data)` para obter `VerificationResult` (Success, Cancelled ou Failure).

### Exemplo

```kotlin
import com.hug.identity.sdk.IdentityService
import com.hug.identity.sdk.IdentityServiceConfig
import com.hug.identity.sdk.VerificationResult

// Iniciar verificação
val config = IdentityServiceConfig(
    baseURL = "https://hugsaudeapigateway.azure-api.net/hug-identity",
    authorizationToken = "Bearer $accessToken",
    userId = user.id.toString(),
    email = user.email,
    phone = user.phone
)
IdentityService.startVerification(this, config, REQUEST_VERIFICATION)

// Em onActivityResult:
override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    if (requestCode == REQUEST_VERIFICATION) {
        when (val result = IdentityService.parseResult(resultCode, data)) {
            is VerificationResult.Success -> { /* verificação concluída */ }
            is VerificationResult.Cancelled -> { /* usuário cancelou */ }
            is VerificationResult.Failure -> { /* exibir result.error */ }
        }
    }
}
```

### Activity Result API

Para usar com `registerForActivityResult`:

```kotlin
val launcher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
    when (IdentityService.parseResult(result.resultCode, result.data)) {
        is VerificationResult.Success -> { }
        is VerificationResult.Cancelled -> { }
        is VerificationResult.Failure -> { }
    }
}
launcher.launch(IdentityService.createVerificationIntent(this, config))
```

## Contrato do backend

- `POST /v1/verification/session` – cria sessão (userId, email, phone). Retorna `verificationSessionId`, `expiresAt`, `maskedEmail`, `maskedPhone`.
- `POST /v1/verification/photo` – envia foto (multipart). Retorna `accepted`, `maskedDestination` (destino onde o código foi enviado).
- `POST /v1/verification/confirm` – confirma código.
- `GET /v1/verification/status?verificationSessionId=...` – status da sessão (opcional).

O código é enviado por um único canal (e-mail com prioridade; SMS se necessário). Documentação do serviço: [HUG-IdentityService](https://github.com/gouriques/HUG-IdentityService) / spec em `spec/`.
