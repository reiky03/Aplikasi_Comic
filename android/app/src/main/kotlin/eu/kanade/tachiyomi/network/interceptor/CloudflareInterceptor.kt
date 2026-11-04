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
        if (!cookieHeader.isNullOrBlank()) {
            val existing = request.header("Cookie")
            val mergedCookie = if (existing.isNullOrBlank()) {
                cookieHeader
            } else {
                val map = linkedMapOf<String, String>()
                existing.split(';').map { it.trim() }.filter { it.isNotEmpty() }.forEach {
                    val eq = it.indexOf('=')
                    if (eq > 0) map[it.substring(0, eq).trim()] = it.substring(eq + 1).trim()
                }
                cookieHeader.split(';').map { it.trim() }.filter { it.isNotEmpty() }.forEach {
                    val eq = it.indexOf('=')
                    if (eq > 0) map[it.substring(0, eq).trim()] = it.substring(eq + 1).trim()
                }
                map.entries.joinToString("; ") { "${it.key}=${it.value}" }
            }
            reqBuilder.header("Cookie", mergedCookie)
        }
        return chain.proceed(reqBuilder.build())
    }
}
