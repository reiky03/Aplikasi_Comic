package keiyoushi.utils

import android.content.SharedPreferences
import eu.kanade.tachiyomi.source.online.HttpSource

fun HttpSource.getPreferences(
    migration: SharedPreferences.() -> Unit = {},
): SharedPreferences = getPreferences(id).also(migration)

fun HttpSource.getPreferencesLazy(
    migration: SharedPreferences.() -> Unit = {},
): Lazy<SharedPreferences> = lazy { getPreferences(migration) }

fun getPreferences(sourceId: Long): SharedPreferences =
    applicationContext.getSharedPreferences("source_$sourceId", 0)
