package com.hug.identity.sdk

/**
 * Resultado do fluxo de verificação de identidade.
 */
sealed class VerificationResult {
    object Success : VerificationResult()
    object Cancelled : VerificationResult()
    data class Failure(val error: Throwable) : VerificationResult()
}
