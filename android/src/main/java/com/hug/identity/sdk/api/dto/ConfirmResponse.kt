package com.hug.identity.sdk.api.dto

import com.google.gson.annotations.SerializedName

internal data class ConfirmResponse(
    @SerializedName("verified") val verified: Boolean,
    @SerializedName("reason") val reason: String? = null
)
