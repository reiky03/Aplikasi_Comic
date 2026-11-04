package eu.kanade.tachiyomi.source

import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.MangasPage

interface CatalogueSource : Source {
    val supportsLatest: Boolean

    suspend fun getPopularManga(page: Int): MangasPage
    suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage
    suspend fun getLatestUpdates(page: Int): MangasPage
}
