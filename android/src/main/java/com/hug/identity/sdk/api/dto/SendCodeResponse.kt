package com.hug.identity.sdk.api.dto

import com.google.gson.annotations.SerializedName

internal data class SendCodeResponse(
    @SerializedName("sent") val sent: Boolean,
    @SerializedName("maskedDestination") val maskedDestination: String? = null,
    @SerializedName("error") val error: String? = null
)
