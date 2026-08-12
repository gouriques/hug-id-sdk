package com.hug.identity.sdk.api.dto

import com.google.gson.annotations.SerializedName

internal data class AvailableChannelDto(
    @SerializedName("channel") val channel: String,
    @SerializedName("maskedDestination") val maskedDestination: String? = null
) {
    val displayTitle: String
        get() = when (channel.lowercase()) {
            "email" -> "E-mail"
            "sms" -> "SMS"
            "whatsapp" -> "WhatsApp"
            else -> channel.uppercase()
        }
}
