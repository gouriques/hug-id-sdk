import Foundation

/// Configuração do SDK para verificação de identidade HUG-Identity.
public struct IdentityServiceConfig {
    /// URL base da API (ex.: https://hugsaudeapigateway.azure-api.net/hug-identity)
    public let baseURL: String
    /// Token de autorização (ex.: Bearer JWT). Opcional; o backend pode usar outro mecanismo (APIM key, etc.).
    public let authorizationToken: String?
    /// Identificador do usuário no app (ex.: id do backend ou CPF).
    public let userId: String
    /// E-mail do usuário para envio do código.
    public let email: String
    /// Telefone em E.164 para envio do SMS.
    public let phone: String
    /// Quando `true`, o SDK solicita permissão de localização e envia coordenadas ao backend nos marcos da verificação.
    public let enableLocationSignals: Bool

    public init(
        baseURL: String,
        authorizationToken: String? = nil,
        userId: String,
        email: String,
        phone: String,
        enableLocationSignals: Bool = false
    ) {
        self.baseURL = baseURL
        self.authorizationToken = authorizationToken
        self.userId = userId
        self.email = email
        self.phone = phone
        self.enableLocationSignals = enableLocationSignals
    }
}
