package eu.kanade.tachiyomi.network.interceptor

import android.webkit.CookieManager
import okhttp3.Interceptor
import okhttp3.Response

class CloudflareInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val urlStr = request.url.toString()
        val cookieHeader = runCatching {
            CookieManager.getInstance().getCookie(urlStr)
        }.getOrNull()

        val reqBuilder = request.newBuilder()
        if (!cookieHeader.isNullOrBlank() && request.header("Cookie").isNullOrBlank()) {
            reqBuilder.header("Cookie", cookieHeader)
        }
        return chain.proceed(reqBuilder.build())
    }
}
