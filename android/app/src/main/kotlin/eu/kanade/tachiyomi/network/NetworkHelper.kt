package eu.kanade.tachiyomi.network

import okhttp3.OkHttpClient

class NetworkHelper {
    val client: OkHttpClient = OkHttpClient.Builder()
        .followRedirects(true)
        .followSslRedirects(true)
        .build()

    val cloudflareClient: OkHttpClient = client
}
