package com.hug.identity.sdk.api.dto

import com.google.gson.annotations.SerializedName

internal data class SendCodeRequest(
    @SerializedName("verificationSessionId") val verificationSessionId: String,
    @SerializedName("channel") val channel: String
)
