package eu.kanade.tachiyomi.source.model

class FilterList(vararg filters: Filter<*>) : ArrayList<Filter<*>>(filters.toList())
