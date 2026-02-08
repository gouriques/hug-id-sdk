package com.hug.identity.sdk.ui

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.FileProvider
import com.hug.identity.sdk.IdentityService
import com.hug.identity.sdk.IdentityServiceConfig
import com.hug.identity.sdk.R
import com.hug.identity.sdk.api.ApiClient
import com.hug.identity.sdk.api.dto.ConfirmRequest
import com.hug.identity.sdk.api.dto.CreateSessionRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.File

class VerificationActivity : AppCompatActivity() {

    private var config: IdentityServiceConfig? = null
    private var sessionId: String = ""
    private var maskedEmail: String? = null
    private var maskedPhone: String? = null
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private var photoFile: File? = null

    private enum class Step { LOADING, TAKE_PHOTO, ENTER_CODE, SUCCESS }

    private var step = Step.LOADING

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_verification)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        title = "Verificação HUG-ID"

        config = IdentityService.getConfigFromIntent(intent)
        if (config == null) {
            setResult(RESULT_CANCELED)
            finish()
            return
        }
        setupListeners()
        startSession()
    }

    override fun onSupportNavigateUp(): Boolean {
        setResult(RESULT_CANCELED)
        finish()
        return true
    }

    private fun setupListeners() {
        findViewById<View>(R.id.buttonPhoto).setOnClickListener { pickOrTakePhoto() }
        findViewById<View>(R.id.buttonConfirm).setOnClickListener { confirmCode() }
    }

    private fun startSession() {
        val cfg = config ?: return
        val api = ApiClient.createApi(cfg)
        scope.launch {
            try {
                val response = withContext(Dispatchers.IO) {
                    api.createSession(
                        CreateSessionRequest(
                            userId = cfg.userId,
                            email = cfg.email,
                            phone = cfg.phone
                        )
                    )
                }
                if (response.isSuccessful) {
                    val body = response.body()!!
                    sessionId = body.verificationSessionId
                    maskedEmail = body.maskedEmail
                    maskedPhone = body.maskedPhone
                    step = Step.TAKE_PHOTO
                    updateUI()
                } else {
                    setFailure("Erro ao criar sessão: ${response.code()}")
                }
            } catch (e: Exception) {
                setFailure("Erro: ${e.message}")
            }
        }
    }

    private fun updateUI() {
        val statusText = findViewById<android.widget.TextView>(R.id.statusText)
        val destinationText = findViewById<android.widget.TextView>(R.id.destinationText)
        val photoSection = findViewById<View>(R.id.photoSection)
        val codeField = findViewById<android.widget.EditText>(R.id.codeField)
        val buttonConfirm = findViewById<View>(R.id.buttonConfirm)

        when (step) {
            Step.LOADING -> {
                statusText.text = "Criando sessão..."
                destinationText.visibility = View.GONE
                photoSection.visibility = View.GONE
                codeField.visibility = View.GONE
                buttonConfirm.visibility = View.GONE
            }
            Step.TAKE_PHOTO -> {
                statusText.text = "Tire uma selfie ou escolha uma foto para enviar."
                destinationText.visibility = View.GONE
                photoSection.visibility = View.VISIBLE
                codeField.visibility = View.GONE
                buttonConfirm.visibility = View.GONE
            }
            Step.ENTER_CODE -> {
                statusText.text = "Digite o código recebido por e-mail ou SMS."
                val parts = listOfNotNull(maskedEmail, maskedPhone).filter { it.isNotBlank() }
                destinationText.text = if (parts.isEmpty()) "" else "Código enviado para: ${parts.joinToString(" e ")}"
                destinationText.visibility = if (parts.isEmpty()) View.GONE else View.VISIBLE
                photoSection.visibility = View.GONE
                codeField.visibility = View.VISIBLE
                buttonConfirm.visibility = View.VISIBLE
            }
            Step.SUCCESS -> {
                statusText.text = "Verificação concluída."
                destinationText.visibility = View.GONE
                photoSection.visibility = View.GONE
                codeField.visibility = View.GONE
                buttonConfirm.visibility = View.GONE
            }
        }
    }

    private fun pickOrTakePhoto() {
        val options = arrayOf("Câmera", "Galeria", "Cancelar")
        AlertDialog.Builder(this)
            .setTitle("Foto")
            .setItems(options) { _, which ->
                when (which) {
                    0 -> openCamera()
                    1 -> openGallery()
                }
            }
            .show()
    }

    private fun openCamera() {
        try {
            photoFile = File(cacheDir, "photo_${System.currentTimeMillis()}.jpg")
            val uri = FileProvider.getUriForFile(this, "${packageName}.hugidentity.fileprovider", photoFile!!)
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                putExtra(MediaStore.EXTRA_OUTPUT, uri)
            }
            startActivityForResult(intent, REQ_CAMERA)
        } catch (e: Exception) {
            Toast.makeText(this, "Erro ao abrir câmera: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun openGallery() {
        val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
        startActivityForResult(intent, REQ_GALLERY)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK) return
        when (requestCode) {
            REQ_CAMERA -> photoFile?.let { uploadPhoto(it) }
            REQ_GALLERY -> data?.data?.let { uri -> uploadPhotoFromUri(uri) }
        }
    }

    private fun uploadPhotoFromUri(uri: Uri) {
        val stream = contentResolver.openInputStream(uri) ?: return
        val file = File(cacheDir, "picked_${System.currentTimeMillis()}.jpg")
        file.outputStream().use { out -> stream.copyTo(out) }
        uploadPhoto(file)
    }

    private fun uploadPhoto(file: File) {
        val cfg = config ?: return
        val api = ApiClient.createApi(cfg)
        findViewById<android.widget.TextView>(R.id.statusText).text = "Enviando foto..."
        findViewById<View>(R.id.buttonPhoto).isEnabled = false
        scope.launch {
            try {
                val requestFile = file.asRequestBody("image/jpeg".toMediaType())
                val part = MultipartBody.Part.createFormData("file", "photo.jpg", requestFile)
                val sessionBody = sessionId.toRequestBody("text/plain".toMediaType())
                val response = withContext(Dispatchers.IO) {
                    api.uploadPhoto(sessionBody, part)
                }
                if (response.isSuccessful && response.body()?.accepted == true) {
                    step = Step.ENTER_CODE
                    updateUI()
                } else {
                    val msg = response.body()?.message ?: "Foto não aceita"
                    Toast.makeText(this@VerificationActivity, msg, Toast.LENGTH_LONG).show()
                }
            } catch (e: Exception) {
                Toast.makeText(this@VerificationActivity, "Erro: ${e.message}", Toast.LENGTH_LONG).show()
            }
            findViewById<View>(R.id.buttonPhoto).isEnabled = true
        }
    }

    private fun confirmCode() {
        val code = findViewById<android.widget.EditText>(R.id.codeField).text?.toString()?.trim() ?: ""
        if (code.length < 6) {
            Toast.makeText(this, "Digite o código de 6 dígitos.", Toast.LENGTH_SHORT).show()
            return
        }
        val cfg = config ?: return
        val api = ApiClient.createApi(cfg)
        findViewById<android.widget.TextView>(R.id.statusText).text = "Verificando..."
        findViewById<View>(R.id.buttonConfirm).isEnabled = false
        scope.launch {
            try {
                val response = withContext(Dispatchers.IO) {
                    api.confirmCode(ConfirmRequest(verificationSessionId = sessionId, code = code.take(6)))
                }
                if (response.isSuccessful && response.body()?.verified == true) {
                    step = Step.SUCCESS
                    updateUI()
                    setResult(RESULT_OK, Intent().apply {
                        putExtra(IdentityService.EXTRA_RESULT, "success")
                    })
                    finish()
                } else {
                    val msg = response.body()?.reason ?: "Código inválido"
                    Toast.makeText(this@VerificationActivity, msg, Toast.LENGTH_LONG).show()
                }
            } catch (e: Exception) {
                Toast.makeText(this@VerificationActivity, "Erro: ${e.message}", Toast.LENGTH_LONG).show()
            }
            findViewById<View>(R.id.buttonConfirm).isEnabled = true
        }
    }

    private fun setFailure(message: String) {
        setResult(RESULT_OK, Intent().apply {
            putExtra(IdentityService.EXTRA_RESULT, "failure")
            putExtra(IdentityService.EXTRA_ERROR_MESSAGE, message)
        })
        finish()
    }

    companion object {
        private const val REQ_CAMERA = 1001
        private const val REQ_GALLERY = 1002
    }
}
