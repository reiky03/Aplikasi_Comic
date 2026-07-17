package eu.kanade.tachiyomi.source

/**
 * Compatibility marker for extensions that expose optional source settings.
 *
 * Kizen does not render an extension's preference screen yet, but the
 * interface must exist so modern APKs can load their HttpSource classes.
 */
interface ConfigurableSource : Source
