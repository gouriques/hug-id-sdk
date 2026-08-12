package com.hug.identity.sdk.api

import com.hug.identity.sdk.api.dto.ConfirmRequest
import com.hug.identity.sdk.api.dto.ConfirmResponse
import com.hug.identity.sdk.api.dto.CreateSessionRequest
import com.hug.identity.sdk.api.dto.CreateSessionResponse
import com.hug.identity.sdk.api.dto.PhotoResponse
import com.hug.identity.sdk.api.dto.SendCodeRequest
import com.hug.identity.sdk.api.dto.SendCodeResponse
import com.hug.identity.sdk.api.dto.SessionLocationRequest
import okhttp3.MultipartBody
import okhttp3.RequestBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.Header
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part

internal interface IdentityApi {

    @POST("v1/verification/session")
    suspend fun createSession(@Body body: CreateSessionRequest): Response<CreateSessionResponse>

    @Multipart
    @POST("v1/verification/photo")
    suspend fun uploadPhoto(
        @Header("X-Verification-Session-Id") sessionIdHeader: String,
        @Part("verificationSessionId") sessionId: RequestBody,
        @Part file: MultipartBody.Part
    ): Response<PhotoResponse>

    @POST("v1/verification/send-code")
    suspend fun sendCode(@Body body: SendCodeRequest): Response<SendCodeResponse>

    @POST("v1/verification/confirm")
    suspend fun confirmCode(@Body body: ConfirmRequest): Response<ConfirmResponse>

    @POST("v1/verification/session/location")
    suspend fun recordSessionLocation(@Body body: SessionLocationRequest): Response<Unit>
}
