package com.hug.identity.sdk.api

import com.hug.identity.sdk.IdentityServiceConfig
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

internal object ApiClient {

    fun createApi(config: IdentityServiceConfig): IdentityApi {
        val baseUrl = config.baseURL.trimEnd('/') + "/"
        val client = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .apply {
                config.authorizationToken?.takeIf { it.isNotBlank() }?.let { token ->
                    addInterceptor(Interceptor { chain ->
                        val request = chain.request().newBuilder()
                            .addHeader("Authorization", if (token.startsWith("Bearer ")) token else "Bearer $token")
                            .build()
                        chain.proceed(request)
                    })
                }
            }
            .build()
        val retrofit = Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
        return retrofit.create(IdentityApi::class.java)
    }
}
