package com.hug.identity.sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.Fragment
import com.hug.identity.sdk.ui.VerificationActivity

/**
 * Serviço de verificação de identidade HUG-Identity (SDK).
 * Apresenta o fluxo: criar sessão → captura de foto → código por SMS/e-mail → confirmação.
 */
object IdentityService {

    private const val EXTRA_BASE_URL = "hug_identity_base_url"
    private const val EXTRA_TOKEN = "hug_identity_token"
    private const val EXTRA_USER_ID = "hug_identity_user_id"
    private const val EXTRA_EMAIL = "hug_identity_email"
    private const val EXTRA_PHONE = "hug_identity_phone"
    const val EXTRA_RESULT = "hug_identity_result" // "success" | "cancelled" | "failure"
    const val EXTRA_ERROR_MESSAGE = "hug_identity_error_message"

    /**
     * Inicia o fluxo de verificação a partir da Activity.
     * @param activity Activity de origem (será usada startActivityForResult)
     * @param config Configuração com baseURL, token (opcional), userId, email, phone
     * @param requestCode Código de requisição para onActivityResult
     */
    @JvmStatic
    fun startVerification(activity: Activity, config: IdentityServiceConfig, requestCode: Int) {
        if (config.userId.isBlank() || config.email.isBlank() || config.phone.isBlank()) {
            return
        }
        val intent = Intent(activity, VerificationActivity::class.java).apply {
            putExtra(EXTRA_BASE_URL, config.baseURL)
            putExtra(EXTRA_TOKEN, config.authorizationToken)
            putExtra(EXTRA_USER_ID, config.userId)
            putExtra(EXTRA_EMAIL, config.email)
            putExtra(EXTRA_PHONE, config.phone)
        }
        activity.startActivityForResult(intent, requestCode)
    }

    /**
     * Cria um launcher para usar com Activity Result API (registerForActivityResult).
     * Use [createVerificationIntent] para obter o Intent e então lance com o contrato
     * StartActivityForResult(), e em onActivityResult use [parseResult] para obter o [VerificationResult].
     */
    @JvmStatic
    fun createVerificationIntent(context: Context, config: IdentityServiceConfig): Intent {
        return Intent(context, VerificationActivity::class.java).apply {
            putExtra(EXTRA_BASE_URL, config.baseURL)
            putExtra(EXTRA_TOKEN, config.authorizationToken)
            putExtra(EXTRA_USER_ID, config.userId)
            putExtra(EXTRA_EMAIL, config.email)
            putExtra(EXTRA_PHONE, config.phone)
        }
    }

    /**
     * Parseia o resultado retornado por VerificationActivity (data intent e resultCode).
     */
    @JvmStatic
    fun parseResult(resultCode: Int, data: Intent?): VerificationResult {
        if (resultCode != AppCompatActivity.RESULT_OK) {
            return VerificationResult.Cancelled
        }
        val result = data?.getStringExtra(EXTRA_RESULT) ?: return VerificationResult.Cancelled
        return when (result) {
            "success" -> VerificationResult.Success
            "failure" -> VerificationResult.Failure(
                Exception(data?.getStringExtra(EXTRA_ERROR_MESSAGE) ?: "Erro desconhecido")
            )
            else -> VerificationResult.Cancelled
        }
    }

    @JvmStatic
    fun getConfigFromIntent(intent: Intent?): IdentityServiceConfig? {
        if (intent == null) return null
        val baseURL = intent.getStringExtra(EXTRA_BASE_URL) ?: return null
        val userId = intent.getStringExtra(EXTRA_USER_ID) ?: return null
        val email = intent.getStringExtra(EXTRA_EMAIL) ?: return null
        val phone = intent.getStringExtra(EXTRA_PHONE) ?: return null
        return IdentityServiceConfig(
            baseURL = baseURL,
            authorizationToken = intent.getStringExtra(EXTRA_TOKEN),
            userId = userId,
            email = email,
            phone = phone
        )
    }
}
