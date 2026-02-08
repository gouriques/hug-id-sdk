package com.hug.identity.sdk.api.dto

import com.google.gson.annotations.SerializedName

internal data class ConfirmRequest(
    @SerializedName("verificationSessionId") val verificationSessionId: String,
    @SerializedName("code") val code: String
)
