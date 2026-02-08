package com.hug.identity.sdk.api.dto

import com.google.gson.annotations.SerializedName

internal data class CreateSessionResponse(
    @SerializedName("verificationSessionId") val verificationSessionId: String,
    @SerializedName("expiresAt") val expiresAt: String,
    @SerializedName("maskedEmail") val maskedEmail: String? = null,
    @SerializedName("maskedPhone") val maskedPhone: String? = null
)
