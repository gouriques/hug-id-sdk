package com.hug.identity.sdk

/**
 * Erros do SDK HUG-Identity.
 */
sealed class IdentityServiceError(message: String) : Exception(message) {
    object InvalidURL : IdentityServiceError("URL do serviço de verificação inválida.")
    object InvalidResponse : IdentityServiceError("Resposta inválida.")
    data class ApiError(val statusCode: Int, val message: String?) : IdentityServiceError(message ?: "Erro da API ($statusCode).")
    data class PhotoRejected(override val message: String) : IdentityServiceError(message)
    data class CodeInvalid(override val message: String) : IdentityServiceError(message)
    data class MissingUserData(override val message: String) : IdentityServiceError(message)
}
