package eu.kanade.tachiyomi.source.online

import eu.kanade.tachiyomi.network.NetworkHelper
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import okhttp3.Headers
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response

abstract class HttpSource : Source {
    abstract val baseUrl: String

    open val supportsLatest: Boolean = false
    open val network: NetworkHelper = NetworkHelper()
    open val client: OkHttpClient = network.client
    open val headers: Headers = headersBuilder().build()

    open fun headersBuilder(): Headers.Builder =
        Headers.Builder()
            .add("User-Agent", USER_AGENT)
            .add("Referer", "$baseUrl/")

    open fun popularMangaRequest(page: Int): Request =
        GET(baseUrl, headers)

    open fun latestUpdatesRequest(page: Int): Request =
        popularMangaRequest(page)

    open fun searchMangaRequest(page: Int, query: String, filters: FilterList): Request =
        popularMangaRequest(page)

    open fun mangaDetailsRequest(manga: SManga): Request =
        GET(baseUrl + manga.url, headers)

    open fun chapterListRequest(manga: SManga): Request =
        GET(baseUrl + manga.url, headers)

    open fun pageListRequest(chapter: SChapter): Request =
        GET(baseUrl + chapter.url, headers)

    open fun imageRequest(page: Page): Request =
        GET(page.imageUrl ?: page.url, headers)

    open fun popularMangaParse(response: Response): MangasPage =
        throw UnsupportedOperationException("popularMangaParse is not implemented")

    open fun latestUpdatesParse(response: Response): MangasPage =
        throw UnsupportedOperationException("latestUpdatesParse is not implemented")

    open fun searchMangaParse(response: Response): MangasPage =
        throw UnsupportedOperationException("searchMangaParse is not implemented")

    open fun mangaDetailsParse(response: Response): SManga =
        throw UnsupportedOperationException("mangaDetailsParse is not implemented")

    open fun chapterListParse(response: Response): List<SChapter> =
        throw UnsupportedOperationException("chapterListParse is not implemented")

    open fun pageListParse(response: Response): List<Page> =
        throw UnsupportedOperationException("pageListParse is not implemented")

    open fun imageUrlParse(response: Response): String =
        response.request.url.toString()

    open fun getFilterList(): FilterList = FilterList()

    fun setUrlWithoutDomain(manga: SManga, url: String) {
        manga.url = stripBaseUrl(url)
    }

    fun setUrlWithoutDomain(chapter: SChapter, url: String) {
        chapter.url = stripBaseUrl(url)
    }

    fun GET(url: String, headers: Headers = this.headers): Request =
        Request.Builder().url(url).headers(headers).get().build()

    private fun stripBaseUrl(url: String): String =
        if (url.startsWith(baseUrl)) url.removePrefix(baseUrl) else url

    companion object {
        private const val USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }
}
