package com.hug.identity.sdk.api.dto

import com.google.gson.annotations.SerializedName

internal data class CreateSessionRequest(
    @SerializedName("userId") val userId: String,
    @SerializedName("email") val email: String,
    @SerializedName("phone") val phone: String
)
