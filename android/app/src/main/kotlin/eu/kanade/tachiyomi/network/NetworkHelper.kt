package eu.kanade.tachiyomi.network

import android.webkit.CookieManager
import com.reikypratama.aplikasi_komik.extensions.DohDns
import eu.kanade.tachiyomi.network.interceptor.CloudflareInterceptor
import eu.kanade.tachiyomi.network.interceptor.UncaughtExceptionInterceptor
import eu.kanade.tachiyomi.network.interceptor.UserAgentInterceptor
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

class NetworkHelper {
    val defaultUserAgentProvider: () -> String = {
        "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36"
    }

    val client: OkHttpClient = OkHttpClient.Builder()
        .cookieJar(WebViewCookieJar)
        .dns(DohDns("cloudflare"))
        .addInterceptor(UncaughtExceptionInterceptor())
        .addInterceptor(UserAgentInterceptor(defaultUserAgentProvider))
        .addInterceptor(CloudflareInterceptor())
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .callTimeout(40, TimeUnit.SECONDS)
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
