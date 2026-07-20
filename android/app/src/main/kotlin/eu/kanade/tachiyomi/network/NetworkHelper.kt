package eu.kanade.tachiyomi.network

import android.webkit.CookieManager
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.OkHttpClient

class NetworkHelper {
    val client: OkHttpClient = OkHttpClient.Builder()
        .cookieJar(WebViewCookieJar)
        .followRedirects(true)
        .followSslRedirects(true)
        .build()

    val cloudflareClient: OkHttpClient = client
}

object WebViewCookieJar : CookieJar {
    override fun loadForRequest(url: HttpUrl): List<Cookie> {
        val raw = runCatching {
            CookieManager.getInstance().getCookie(url.toString())
        }.getOrNull().orEmpty()
        if (raw.isBlank()) return emptyList()
        return raw.split(';')
            .mapNotNull { part -> Cookie.parse(url, part.trim()) }
    }

    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        if (cookies.isEmpty()) return
        runCatching {
            val manager = CookieManager.getInstance()
            cookies.forEach { cookie ->
                manager.setCookie(url.toString(), cookie.toString())
            }
            manager.flush()
        }
    }
}
