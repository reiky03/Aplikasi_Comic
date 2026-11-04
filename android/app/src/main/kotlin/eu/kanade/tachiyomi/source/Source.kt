package eu.kanade.tachiyomi.source

import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga

interface Source {
    val id: Long
    val name: String
    val lang: String

    suspend fun getMangaDetails(manga: SManga): SManga = manga
    suspend fun getChapterList(manga: SManga): List<SChapter> = emptyList()
    suspend fun getPageList(chapter: SChapter): List<Page> = emptyList()
    suspend fun getImageUrl(page: Page): String = page.imageUrl ?: page.url
}
