package com.hug.identity.sdk.api

import com.hug.identity.sdk.api.dto.ConfirmRequest
import com.hug.identity.sdk.api.dto.ConfirmResponse
import com.hug.identity.sdk.api.dto.CreateSessionRequest
import com.hug.identity.sdk.api.dto.CreateSessionResponse
import com.hug.identity.sdk.api.dto.PhotoResponse
import okhttp3.RequestBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part

internal interface IdentityApi {

    @POST("v1/verification/session")
    suspend fun createSession(@Body body: CreateSessionRequest): Response<CreateSessionResponse>

    @retrofit2.http.Multipart
    @POST("v1/verification/photo")
    suspend fun uploadPhoto(
        @Part("verificationSessionId") sessionId: RequestBody,
        @Part file: okhttp3.MultipartBody.Part
    ): Response<PhotoResponse>

    @POST("v1/verification/confirm")
    suspend fun confirmCode(@Body body: ConfirmRequest): Response<ConfirmResponse>
}
