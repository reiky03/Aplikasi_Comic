package eu.kanade.tachiyomi.network

import okhttp3.CacheControl
import okhttp3.Headers
import okhttp3.HttpUrl
import okhttp3.Request
import okhttp3.RequestBody

fun GET(
    url: String,
    headers: Headers = Headers.headersOf(),
    cache: CacheControl? = null,
): Request {
    val builder = Request.Builder().url(url).headers(headers).get()
    if (cache != null) builder.cacheControl(cache)
    return builder.build()
}

fun GET(
    url: HttpUrl,
    headers: Headers = Headers.headersOf(),
    cache: CacheControl? = null,
): Request {
    val builder = Request.Builder().url(url).headers(headers).get()
    if (cache != null) builder.cacheControl(cache)
    return builder.build()
}

fun POST(
    url: String,
    headers: Headers = Headers.headersOf(),
    body: RequestBody = RequestBody.create(null, ByteArray(0)),
    cache: CacheControl? = null,
): Request {
    val builder = Request.Builder().url(url).headers(headers).post(body)
    if (cache != null) builder.cacheControl(cache)
    return builder.build()
}

fun POST(
    url: HttpUrl,
    headers: Headers = Headers.headersOf(),
    body: RequestBody = RequestBody.create(null, ByteArray(0)),
    cache: CacheControl? = null,
): Request {
    val builder = Request.Builder().url(url).headers(headers).post(body)
    if (cache != null) builder.cacheControl(cache)
    return builder.build()
}
