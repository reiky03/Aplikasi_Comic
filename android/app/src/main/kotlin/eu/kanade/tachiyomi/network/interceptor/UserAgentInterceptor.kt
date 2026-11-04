package eu.kanade.tachiyomi.network.interceptor

import okhttp3.Interceptor
import okhttp3.Response

class UserAgentInterceptor(
    private val defaultUserAgentProvider: () -> String = {
        "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36"
    },
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        return if (original.header("User-Agent").isNullOrEmpty()) {
            val req = original.newBuilder()
                .header("User-Agent", defaultUserAgentProvider())
                .build()
            chain.proceed(req)
        } else {
            chain.proceed(original)
        }
    }
}
