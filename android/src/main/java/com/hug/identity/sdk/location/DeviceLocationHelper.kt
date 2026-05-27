package com.hug.identity.sdk.location

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.os.Looper
import android.provider.Settings
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

data class DeviceLocationSample(
    val latitude: Double,
    val longitude: Double,
    val accuracyMeters: Float?,
    val source: String,
    val capturedAtMillis: Long
)

object DeviceLocationHelper {

    suspend fun capture(
        activity: AppCompatActivity,
        onRequestPermission: suspend () -> Boolean
    ): DeviceLocationSample? {
        if (!hasFineLocationPermission(activity)) {
            val granted = onRequestPermission()
            if (!granted) {
                showSettingsDialog(activity)
                return null
            }
        }
        if (!hasFineLocationPermission(activity)) {
            showSettingsDialog(activity)
            return null
        }
        return readBestLocation(activity)
    }

    fun hasFineLocationPermission(context: Context): Boolean =
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

    private suspend fun readBestLocation(context: Context): DeviceLocationSample? {
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            ?: return null

        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER
        ).filter { manager.isProviderEnabled(it) }

        var best: Location? = null
        for (provider in providers) {
            val last = try {
                manager.getLastKnownLocation(provider)
            } catch (_: SecurityException) {
                null
            }
            if (last != null && (best == null || last.time > best!!.time)) {
                best = last
            }
        }

        if (best != null) {
            return best.toSample()
        }

        if (providers.isEmpty()) return null

        return suspendCancellableCoroutine { cont ->
            val provider = providers.first()
            try {
                manager.requestSingleUpdate(
                    provider,
                    { location ->
                        if (cont.isActive) {
                            cont.resume(location?.toSample())
                        }
                    },
                    Looper.getMainLooper()
                )
            } catch (_: SecurityException) {
                if (cont.isActive) cont.resume(null)
            } catch (_: Exception) {
                if (cont.isActive) cont.resume(null)
            }
        }
    }

    private fun Location.toSample() = DeviceLocationSample(
        latitude = latitude,
        longitude = longitude,
        accuracyMeters = if (hasAccuracy()) accuracy else null,
        source = provider?.ifBlank { "gps" } ?: "gps",
        capturedAtMillis = time
    )

    private fun showSettingsDialog(activity: AppCompatActivity) {
        if (activity.isFinishing) return
        AlertDialog.Builder(activity)
            .setTitle("Localização")
            .setMessage(
                "Para reforçar a segurança da verificação, permita o acesso à localização nas configurações do app."
            )
            .setNegativeButton("Cancelar", null)
            .setPositiveButton("Configurações") { _, _ ->
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", activity.packageName, null)
                }
                activity.startActivity(intent)
            }
            .show()
    }
}
