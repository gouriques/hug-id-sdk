package com.hug.identity.sdk

/**
 * Configuração do SDK para verificação de identidade HUG-Identity.
 *
 * @param baseURL URL base da API (ex.: https://hugsaudeapigateway.azure-api.net/hug-identity)
 * @param authorizationToken Token de autorização (ex.: Bearer JWT). Opcional.
 * @param apimSubscriptionKey Chave `Ocp-Apim-Subscription-Key` do gateway (recomendado no APIM HUG).
 * @param userId Identificador do usuário no app (ex.: id do backend ou CPF)
 * @param email E-mail do usuário para envio do código
 * @param phone Telefone em E.164 para envio do SMS
 * @param enableLocationSignals Quando true, solicita localização e envia ao backend nos marcos da verificação
 */
data class IdentityServiceConfig(
    val baseURL: String,
    val authorizationToken: String? = null,
    val apimSubscriptionKey: String? = null,
    val userId: String,
    val email: String,
    val phone: String,
    val enableLocationSignals: Boolean = false
)
