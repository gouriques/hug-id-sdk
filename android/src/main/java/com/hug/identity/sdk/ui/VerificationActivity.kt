package com.hug.identity.sdk.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import android.view.View
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.ActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.lifecycle.lifecycleScope
import com.google.gson.Gson
import com.hug.identity.sdk.IdentityService
import com.hug.identity.sdk.IdentityServiceConfig
import com.hug.identity.sdk.R
import com.hug.identity.sdk.api.ApiClient
import com.hug.identity.sdk.api.dto.ConfirmRequest
import com.hug.identity.sdk.api.dto.CreateSessionRequest
import com.hug.identity.sdk.api.dto.PhotoResponse
import com.hug.identity.sdk.api.dto.SessionLocationRequest
import com.hug.identity.sdk.location.DeviceLocationHelper
import com.hug.identity.sdk.location.DeviceLocationSample
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.Response
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import kotlin.coroutines.resume
import kotlin.math.max
import kotlin.math.roundToInt
import kotlinx.coroutines.suspendCancellableCoroutine

class VerificationActivity : AppCompatActivity() {

    private var config: IdentityServiceConfig? = null
    private var sessionId: String = ""
    private var maskedEmail: String? = null
    private var maskedPhone: String? = null
    private var maskedDestinationFromPhoto: String? = null
    private var photoFile: File? = null

    private val requestCameraPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) launchCameraIntent()
        else onCameraPermissionDenied()
    }

    private val cameraLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result -> handleCameraResult(result) }

    private val galleryLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        if (uri == null) return@registerForActivityResult
        copyUriToCacheFile(uri)?.let { uploadPhoto(it) }
            ?: showUploadError("Não foi possível ler a imagem da galeria.")
    }

    private var locationPermissionContinuation: ((Boolean) -> Unit)? = null

    private val requestLocationPermission = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        val granted = results[Manifest.permission.ACCESS_FINE_LOCATION] == true
        locationPermissionContinuation?.invoke(granted)
        locationPermissionContinuation = null
    }

    private enum class Step { LOADING, TAKE_PHOTO, UPLOADING, ENTER_CODE, SUCCESS }

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
        maskedDestinationFromPhoto = null
        val cfg = config ?: return
        val api = ApiClient.createApi(cfg)
        lifecycleScope.launch {
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
                    val body = response.body()
                    if (body == null) {
                        setFailure("Resposta inválida ao criar sessão.")
                        return@launch
                    }
                    sessionId = body.verificationSessionId
                    maskedEmail = body.maskedEmail
                    maskedPhone = body.maskedPhone
                    step = Step.TAKE_PHOTO
                    updateUI()
                    submitLocationIfEnabled("verification-session-start")
                } else {
                    setFailure("Erro ao criar sessão: ${response.code()}")
                }
            } catch (e: Exception) {
                setFailure("Erro: ${e.message}")
            }
        }
    }

    private fun updateUI() {
        if (isFinishing) return
        val statusText = findViewById<TextView>(R.id.statusText)
        val destinationText = findViewById<TextView>(R.id.destinationText)
        val photoSection = findViewById<View>(R.id.photoSection)
        val codeField = findViewById<android.widget.EditText>(R.id.codeField)
        val buttonConfirm = findViewById<View>(R.id.buttonConfirm)
        val buttonPhoto = findViewById<View>(R.id.buttonPhoto)
        val uploadProgress = findViewById<ProgressBar>(R.id.uploadProgress)

        when (step) {
            Step.LOADING -> {
                statusText.text = "Criando sessão..."
                destinationText.visibility = View.GONE
                photoSection.visibility = View.GONE
                codeField.visibility = View.GONE
                buttonConfirm.visibility = View.GONE
                uploadProgress.visibility = View.GONE
            }
            Step.TAKE_PHOTO -> {
                statusText.text = "Tire uma selfie para enviar."
                destinationText.visibility = View.GONE
                photoSection.visibility = View.VISIBLE
                codeField.visibility = View.GONE
                buttonConfirm.visibility = View.GONE
                buttonPhoto.isEnabled = true
                uploadProgress.visibility = View.GONE
            }
            Step.UPLOADING -> {
                statusText.text = "Enviando foto... Aguarde."
                destinationText.visibility = View.GONE
                photoSection.visibility = View.VISIBLE
                codeField.visibility = View.GONE
                buttonConfirm.visibility = View.GONE
                buttonPhoto.isEnabled = false
                uploadProgress.visibility = View.VISIBLE
            }
            Step.ENTER_CODE -> {
                statusText.text = "Digite o código recebido por e-mail ou SMS."
                val dest = maskedDestinationFromPhoto?.takeIf { it.isNotBlank() }
                destinationText.text = when {
                    dest != null -> "Código enviado para: $dest"
                    else -> {
                        val parts = listOfNotNull(maskedEmail, maskedPhone).filter { it.isNotBlank() }
                        if (parts.isEmpty()) "" else "Código enviado para: ${parts.joinToString(" e ")}"
                    }
                }
                destinationText.visibility =
                    if (destinationText.text.isNullOrBlank()) View.GONE else View.VISIBLE
                photoSection.visibility = View.GONE
                codeField.visibility = View.VISIBLE
                buttonConfirm.visibility = View.VISIBLE
                uploadProgress.visibility = View.GONE
            }
            Step.SUCCESS -> {
                statusText.text = "Verificação concluída."
                destinationText.visibility = View.GONE
                photoSection.visibility = View.GONE
                codeField.visibility = View.GONE
                buttonConfirm.visibility = View.GONE
                uploadProgress.visibility = View.GONE
            }
        }
    }

    private fun pickOrTakePhoto() {
        val options = arrayOf("Câmera", "Galeria", "Cancelar")
        AlertDialog.Builder(this)
            .setTitle("Foto")
            .setItems(options) { _, which ->
                when (which) {
                    0 -> ensureCameraPermissionAndOpen()
                    1 -> galleryLauncher.launch("image/*")
                }
            }
            .show()
    }

    private fun handleCameraResult(result: ActivityResult) {
        if (result.resultCode != RESULT_OK) return
        val file = resolveCaptureToFile(result)
        if (file == null) {
            showUploadError(
                "A foto não foi gravada no dispositivo. No emulador, use Galeria ou tente novamente."
            )
            return
        }
        uploadPhoto(file)
    }

    private fun resolveCaptureToFile(result: ActivityResult): File? {
        photoFile?.takeIf { it.exists() && it.length() > 0L }?.let { return it }

        val data = result.data ?: return null
        val thumbnail = readThumbnailBitmap(data)
        if (thumbnail != null) {
            return writeBitmapToCacheFile(thumbnail)
        }
        data.data?.let { uri -> return copyUriToCacheFile(uri) }
        return null
    }

    private fun readThumbnailBitmap(data: Intent): Bitmap? {
        val extras = data.extras ?: return null
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            extras.getParcelable("data", Bitmap::class.java)
        } else {
            @Suppress("DEPRECATION")
            extras.get("data") as? Bitmap
        }
    }

    private fun writeBitmapToCacheFile(bitmap: Bitmap): File? {
        return try {
            val out = File(cacheDir, "photo_capture_${System.currentTimeMillis()}.jpg")
            FileOutputStream(out).use { stream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, stream)
            }
            if (out.length() > 0L) out else null
        } catch (e: Exception) {
            Log.e(TAG, "writeBitmapToCacheFile failed", e)
            null
        } finally {
            if (!bitmap.isRecycled) bitmap.recycle()
        }
    }

    private fun copyUriToCacheFile(uri: Uri): File? {
        return try {
            val out = File(cacheDir, "photo_gallery_${System.currentTimeMillis()}.jpg")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(out).use { output -> input.copyTo(output) }
            } ?: return null
            if (out.length() > 0L) out else null
        } catch (e: Exception) {
            Log.e(TAG, "copyUriToCacheFile failed", e)
            null
        }
    }

    private fun ensureCameraPermissionAndOpen() {
        when {
            ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED -> launchCameraIntent()
            shouldShowRequestPermissionRationale(Manifest.permission.CAMERA) -> {
                AlertDialog.Builder(this)
                    .setMessage(R.string.hug_identity_camera_permission_rationale)
                    .setPositiveButton(android.R.string.ok) { _, _ ->
                        requestCameraPermission.launch(Manifest.permission.CAMERA)
                    }
                    .setNegativeButton(android.R.string.cancel, null)
                    .show()
            }
            else -> requestCameraPermission.launch(Manifest.permission.CAMERA)
        }
    }

    private fun onCameraPermissionDenied() {
        if (!shouldShowRequestPermissionRationale(Manifest.permission.CAMERA)) {
            AlertDialog.Builder(this)
                .setMessage(R.string.hug_identity_camera_permission_settings)
                .setPositiveButton(R.string.hug_identity_open_settings) { _, _ ->
                    startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                        }
                    )
                }
                .setNegativeButton(android.R.string.cancel, null)
                .show()
        } else {
            Toast.makeText(
                this,
                R.string.hug_identity_camera_permission_denied,
                Toast.LENGTH_LONG
            ).show()
        }
    }

    private fun launchCameraIntent() {
        try {
            photoFile = File(cacheDir, "photo_${System.currentTimeMillis()}.jpg")
            val uri = FileProvider.getUriForFile(
                this,
                "${packageName}.hugidentity.fileprovider",
                photoFile!!
            )
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                putExtra(MediaStore.EXTRA_OUTPUT, uri)
                addFlags(
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            }
            val cameraApps = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            for (resolve in cameraApps) {
                grantUriPermission(
                    resolve.activityInfo.packageName,
                    uri,
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            }
            cameraLauncher.launch(intent)
        } catch (e: Exception) {
            showUploadError("Erro ao abrir câmera: ${e.message}")
        }
    }

    private fun uploadPhoto(file: File) {
        if (!file.exists() || file.length() == 0L) {
            showUploadError(
                "A foto não foi gravada no dispositivo. Tire a foto novamente (a câmera precisa salvar a imagem)."
            )
            return
        }
        val cfg = config ?: return
        step = Step.UPLOADING
        updateUI()

        lifecycleScope.launch {
            try {
                val api = ApiClient.createApi(cfg)
                val uploadResult = withContext(Dispatchers.IO) {
                    performPhotoUpload(api, file)
                }
                when (uploadResult) {
                    is PhotoUploadResult.Success -> {
                        maskedDestinationFromPhoto = uploadResult.maskedDestination
                        submitLocationIfEnabled("verification-photo-uploaded")
                        step = Step.ENTER_CODE
                        updateUI()
                    }
                    is PhotoUploadResult.Error -> showUploadError(uploadResult.message)
                }
            } catch (e: Exception) {
                Log.e(TAG, "uploadPhoto failed", e)
                showUploadError("Erro de rede ao enviar foto: ${e.message ?: e.javaClass.simpleName}")
            }
        }
    }

    private suspend fun performPhotoUpload(
        api: com.hug.identity.sdk.api.IdentityApi,
        sourceFile: File
    ): PhotoUploadResult {
        val prepared = prepareUploadFile(sourceFile)
        val requestFile = prepared.asRequestBody("image/jpeg".toMediaType())
        val part = MultipartBody.Part.createFormData("file", "photo.jpg", requestFile)
        val sessionBody = sessionId.toRequestBody("text/plain".toMediaType())
        val response = api.uploadPhoto(
            sessionIdHeader = sessionId,
            sessionId = sessionBody,
            file = part
        )
        if (prepared != sourceFile) prepared.delete()
        return parsePhotoUploadResponse(response)
    }

    private fun parsePhotoUploadResponse(response: Response<PhotoResponse>): PhotoUploadResult {
        if (response.isSuccessful) {
            val body = response.body()
            if (body?.accepted == true) {
                return PhotoUploadResult.Success(body.maskedDestination)
            }
            if (body == null) {
                val raw = response.raw().peekBody(64 * 1024).string()
                val parsed = runCatching { gson.fromJson(raw, PhotoResponse::class.java) }.getOrNull()
                if (parsed?.accepted == true) {
                    return PhotoUploadResult.Success(parsed.maskedDestination)
                }
            }
            return PhotoUploadResult.Error(
                body?.message?.takeIf { it.isNotBlank() }
                    ?: "Foto não aceita pelo servidor."
            )
        }
        return PhotoUploadResult.Error(resolvePhotoUploadError(response))
    }

    private fun resolvePhotoUploadError(response: Response<PhotoResponse>): String {
        response.body()?.message?.takeIf { it.isNotBlank() }?.let { return it }
        val raw = response.errorBody()?.string().orEmpty()
        if (raw.isNotBlank()) {
            runCatching { gson.fromJson(raw, PhotoResponse::class.java) }.getOrNull()
                ?.message
                ?.takeIf { it.isNotBlank() }
                ?.let { return it }
            return raw.take(800)
        }
        return when (response.code()) {
            401 -> "Não autorizado (401). Verifique login e chave do APIM."
            403 -> "Acesso negado (403) ao enviar a foto."
            413 -> "Foto muito grande para o servidor."
            else -> "Erro ao enviar foto (HTTP ${response.code()})."
        }
    }

    private fun prepareUploadFile(source: File): File {
        val bitmap = BitmapFactory.decodeFile(source.absolutePath) ?: return source
        return try {
            val scaled = scaleBitmap(bitmap, MAX_UPLOAD_DIMENSION_PX)
            val out = File(cacheDir, "photo_upload_${System.currentTimeMillis()}.jpg")
            FileOutputStream(out).use { stream ->
                scaled.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, stream)
            }
            if (scaled !== bitmap) scaled.recycle()
            out
        } finally {
            bitmap.recycle()
        }
    }

    private fun scaleBitmap(bitmap: Bitmap, maxDimension: Int): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val largest = max(width, height)
        if (largest <= maxDimension) return bitmap
        val scale = maxDimension.toFloat() / largest.toFloat()
        val targetW = (width * scale).roundToInt().coerceAtLeast(1)
        val targetH = (height * scale).roundToInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, targetW, targetH, true)
    }

    private fun showUploadError(message: String) {
        Log.e(TAG, message)
        if (isFinishing) return
        step = Step.TAKE_PHOTO
        updateUI()
        findViewById<TextView>(R.id.statusText).text = message
        AlertDialog.Builder(this)
            .setTitle("Envio da foto")
            .setMessage(message)
            .setPositiveButton(android.R.string.ok, null)
            .show()
    }

    private fun confirmCode() {
        val code = findViewById<android.widget.EditText>(R.id.codeField).text?.toString()?.trim() ?: ""
        if (code.length < 6) {
            Toast.makeText(this, "Digite o código de 6 dígitos.", Toast.LENGTH_SHORT).show()
            return
        }
        val cfg = config ?: return
        val api = ApiClient.createApi(cfg)
        findViewById<TextView>(R.id.statusText).text = "Verificando..."
        findViewById<View>(R.id.buttonConfirm).isEnabled = false
        lifecycleScope.launch {
            try {
                val response = withContext(Dispatchers.IO) {
                    api.confirmCode(ConfirmRequest(verificationSessionId = sessionId, code = code.take(6)))
                }
                if (response.isSuccessful && response.body()?.verified == true) {
                    submitLocationIfEnabled("verification-code-confirmed")
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
            if (!isFinishing) {
                findViewById<View>(R.id.buttonConfirm).isEnabled = true
            }
        }
    }

    private sealed class PhotoUploadResult {
        data class Success(val maskedDestination: String?) : PhotoUploadResult()
        data class Error(val message: String) : PhotoUploadResult()
    }

    private fun submitLocationIfEnabled(context: String) {
        val cfg = config ?: return
        if (!cfg.enableLocationSignals || sessionId.isBlank()) return
        lifecycleScope.launch {
            runCatching {
                val sample = DeviceLocationHelper.capture(
                    activity = this@VerificationActivity,
                    onRequestPermission = { requestLocationPermissionAsync() }
                ) ?: return@runCatching
                val api = ApiClient.createApi(cfg)
                withContext(Dispatchers.IO) {
                    api.recordSessionLocation(sample.toRequest(cfg.userId, sessionId, context))
                }
            }
            // Best-effort: falhas de localização não bloqueiam a verificação.
        }
    }

    private suspend fun requestLocationPermissionAsync(): Boolean {
        if (DeviceLocationHelper.hasFineLocationPermission(this)) return true
        return suspendCancellableCoroutine { cont ->
            locationPermissionContinuation = { granted ->
                if (cont.isActive) cont.resume(granted)
            }
            requestLocationPermission.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                )
            )
        }
    }

    private fun DeviceLocationSample.toRequest(
        userId: String,
        verificationSessionId: String,
        contexto: String
    ): SessionLocationRequest {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }
        return SessionLocationRequest(
            verificationSessionId = verificationSessionId,
            userId = userId,
            contexto = contexto,
            latitude = latitude,
            longitude = longitude,
            accuracyMetros = accuracyMeters?.toDouble(),
            fonte = source,
            capturadoEm = formatter.format(capturedAtMillis)
        )
    }

    private fun setFailure(message: String) {
        setResult(RESULT_OK, Intent().apply {
            putExtra(IdentityService.EXTRA_RESULT, "failure")
            putExtra(IdentityService.EXTRA_ERROR_MESSAGE, message)
        })
        finish()
    }

    companion object {
        private const val TAG = "HUGIdentitySDK"
        private val gson = Gson()
        private const val MAX_UPLOAD_DIMENSION_PX = 1280
        private const val JPEG_QUALITY = 85
    }
}
