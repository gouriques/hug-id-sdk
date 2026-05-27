package com.hug.identity.sdk.api.dto

import com.google.gson.annotations.SerializedName

data class SessionLocationRequest(
    @SerializedName("verificationSessionId") val verificationSessionId: String,
    @SerializedName("userId") val userId: String,
    @SerializedName("contexto") val contexto: String,
    @SerializedName("latitude") val latitude: Double,
    @SerializedName("longitude") val longitude: Double,
    @SerializedName("accuracyMetros") val accuracyMetros: Double? = null,
    @SerializedName("fonte") val fonte: String = "gps",
    @SerializedName("capturadoEm") val capturadoEm: String? = null
)
