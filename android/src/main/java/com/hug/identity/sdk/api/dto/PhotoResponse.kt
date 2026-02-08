package com.hug.identity.sdk.api.dto

import com.google.gson.annotations.SerializedName

internal data class PhotoResponse(
    @SerializedName("accepted") val accepted: Boolean,
    @SerializedName("message") val message: String? = null
)
