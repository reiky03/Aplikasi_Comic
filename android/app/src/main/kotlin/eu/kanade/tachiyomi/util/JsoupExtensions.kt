package eu.kanade.tachiyomi.util

import okhttp3.Response
import org.jsoup.Jsoup
import org.jsoup.nodes.Document

fun Response.asJsoup(html: String? = null): Document {
    val body = html ?: body.string()
    return Jsoup.parse(body, request.url.toString())
}
