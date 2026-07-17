package com.reikypratama.aplikasi_komik.extensions

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
import android.webkit.CookieManager
import android.webkit.WebSettings
import androidx.core.content.FileProvider
import dalvik.system.DexClassLoader
import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import java.io.File
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Headers
import org.json.JSONArray
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import uy.kohesive.injekt.installApplication

class ExtensionRuntimeBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    init {
        (context.applicationContext as? android.app.Application)?.let(::installApplication)
    }

    private lateinit var channel: MethodChannel
    private val sourceCache = mutableMapOf<String, List<LoadedExtensionSource>>()
    private val sourceCacheLock = Any()

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "runtimeInfo" -> result.success(runtimeInfo())
            "readWebViewSession" -> readWebViewSession(call, result)
            "listInstalledExtensions" -> result.success(listInstalledExtensions())
            "installExtensionApk" -> installExtensionApk(call, result)
            "uninstallExtensionPackage" -> uninstallExtensionPackage(call, result)
            "inspectExtension" -> inspectExtension(call, result)
            "listExtensionSources" -> listExtensionSources(call, result)
            "fetchPopularFromExtension" -> fetchPopularFromExtension(call, result)
            "fetchLatestFromExtension" -> fetchMangaPageFromExtension(call, result, "latest")
            "fetchSearchFromExtension" -> fetchMangaPageFromExtension(call, result, "search")
            "fetchMangaDetailsFromExtension" -> fetchMangaDetailsFromExtension(call, result)
            "fetchChapterListFromExtension" -> fetchChapterListFromExtension(call, result)
            "fetchPageListFromExtension" -> fetchPageListFromExtension(call, result)
            else -> result.notImplemented()
        }
    }

    private fun runtimeInfo(): Map<String, Any?> = mapOf(
        "platform" to "android",
        "apiVersion" to API_VERSION,
        "available" to true,
        "message" to "Android extension runtime bridge ready",
        "capabilities" to mapOf(
            "packageDiscovery" to true,
            "apkClassLoading" to true,
            "tachiyomiSourceApi" to true,
            "tachiyomiSourceFactory" to true,
            "networkBridge" to true,
        ),
    )

    private fun readWebViewSession(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.error("bad_args", "url kosong", null)
            return
        }
        try {
            CookieManager.getInstance().flush()
            result.success(
                mapOf(
                    "url" to url,
                    "cookie" to CookieManager.getInstance().getCookie(url),
                    "userAgent" to WebSettings.getDefaultUserAgent(context),
                ),
            )
        } catch (e: Throwable) {
            result.error("session_failed", e.safeMessage(), e.stackTraceToString())
        }
    }

    private fun installExtensionApk(call: MethodCall, result: MethodChannel.Result) {
        val apkUrl = call.argument<String>("apkUrl")
        val rawFileName = call.argument<String>("fileName")
        if (apkUrl.isNullOrBlank()) {
            result.error("bad_args", "apkUrl kosong", null)
            return
        }

        Thread {
            try {
                val fileName = rawFileName
                    ?.substringAfterLast('/')
                    ?.replace(Regex("[^A-Za-z0-9._-]"), "_")
                    ?.takeIf { it.endsWith(".apk", ignoreCase = true) }
                    ?: "tachiyomi-extension.apk"
                val dir = File(context.cacheDir, "extension-apks").apply { mkdirs() }
                val apkFile = File(dir, fileName)
                val request = Request.Builder()
                    .url(apkUrl)
                    .header(
                        "User-Agent",
                        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                    )
                    .get()
                    .build()
                OkHttpClient().newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Download APK gagal: HTTP ${response.code}")
                    }
                    apkFile.outputStream().use { output ->
                        response.body.byteStream().copyTo(output)
                    }
                }
                val uri = FileProvider.getUriForFile(
                    context,
                    "${context.packageName}.fileprovider",
                    apkFile,
                )
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, APK_MIME_TYPE)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                context.startActivity(intent)
                Log.i(TAG, "installExtensionApk opened installer for $apkUrl")
                result.success(null)
            } catch (e: Throwable) {
                Log.e(TAG, "installExtensionApk failed for $apkUrl", e)
                result.error("install_failed", e.safeMessage(), e.stackTraceToString())
            }
        }.start()
    }

    private fun uninstallExtensionPackage(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")
        if (packageName.isNullOrBlank()) {
            result.error("bad_args", "packageName kosong", null)
            return
        }
        if (!packageName.isTachiyomiExtensionPackage()) {
            result.error("bad_args", "Bukan package extension: $packageName", null)
            return
        }

        try {
            val intent = Intent(Intent.ACTION_DELETE).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            Log.i(TAG, "uninstallExtensionPackage opened uninstaller for $packageName")
            result.success(null)
        } catch (e: Throwable) {
            Log.e(TAG, "uninstallExtensionPackage failed for $packageName", e)
            result.error("uninstall_failed", e.safeMessage(), e.stackTraceToString())
        }
    }

    private fun listInstalledExtensions(): List<Map<String, Any?>> {
        val packageManager = context.packageManager
        return installedPackages(packageManager)
            .asSequence()
            .filter { it.packageName.isTachiyomiExtensionPackage() }
            .sortedBy { it.packageName }
            .map { info ->
                val appInfo = info.applicationInfo
                val label = appInfo?.loadLabel(packageManager)?.toString()
                mapOf(
                    "packageName" to info.packageName,
                    "name" to (label ?: info.packageName),
                    "versionName" to info.versionName,
                    "versionCode" to info.longVersionCodeCompat(),
                    "extensionClass" to extensionClassName(info.applicationInfo),
                    "sourceDir" to info.applicationInfo?.sourceDir,
                    "installed" to true,
                )
            }
            .toList()
    }

    private fun inspectExtension(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")
        if (packageName.isNullOrBlank()) {
            result.error("bad_args", "packageName kosong", null)
            return
        }
        try {
            val source = loadExtensionSource(packageName)
            val sourceMap = source.toMap()
            Log.i(TAG, "inspectExtension OK ${source.packageName} -> ${sourceMap["name"]}")
            result.success(sourceMap)
        } catch (e: Throwable) {
            Log.e(TAG, "inspectExtension failed for $packageName", e)
            result.error("inspect_failed", e.safeMessage(), e.stackTraceToString())
        }
    }

    private fun listExtensionSources(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")
        if (packageName.isNullOrBlank()) {
            result.error("bad_args", "packageName kosong", null)
            return
        }
        Thread {
            try {
                result.success(loadAllExtensionSources(packageName).map { it.toMap() })
            } catch (e: Throwable) {
                Log.e(TAG, "listExtensionSources failed for $packageName", e)
                result.error("inspect_failed", e.safeMessage(), e.stackTraceToString())
            }
        }.start()
    }

    private fun fetchPopularFromExtension(call: MethodCall, result: MethodChannel.Result) {
        fetchMangaPageFromExtension(call, result, "popular")
    }

    private fun fetchMangaPageFromExtension(
        call: MethodCall,
        result: MethodChannel.Result,
        mode: String,
    ) {
        val packageName = call.argument<String>("packageName")
        val page = call.argument<Int>("page") ?: 1
        val query = call.argument<String>("query") ?: ""
        if (packageName.isNullOrBlank()) {
            result.error("bad_args", "packageName kosong", null)
            return
        }

        Thread {
            try {
                val source = loadExtensionSource(
                    packageName,
                    call.argument<String>("sourceName"),
                    call.argument<String>("sourceLang"),
                    call.argument<String>("baseUrl"),
                )
                val sessionHeaders = call.sessionHeaders()
                val request = when (mode) {
                    "latest" -> source.instance.call("latestUpdatesRequest", page) as Request
                    "search" -> source.instance.call(
                        "searchMangaRequest",
                        page,
                        query,
                        source.instance.callOrNull("getFilterList") as? FilterList
                            ?: FilterList(),
                    ) as Request
                    else -> source.instance.call("popularMangaRequest", page) as Request
                }.withSessionHeaders(sessionHeaders)
                val client = source.instance.callOrNull("getClient") as? OkHttpClient
                    ?: OkHttpClient()
                client.newCall(request).execute().use { response ->
                    val responsePreview = response.peekBody(2L * 1024L * 1024L).string()
                    val parseMethod = when (mode) {
                        "latest" -> "latestUpdatesParse"
                        "search" -> "searchMangaParse"
                        else -> "popularMangaParse"
                    }
                    val parsed = runCatching {
                        source.instance.call(parseMethod, response)
                            ?: throw IllegalStateException("$parseMethod mengembalikan null")
                    }.getOrElse { parseError ->
                        if (packageName.contains("doujindesu") && mode != "search") {
                            val fallback = parseDoujindesuMangas(
                                responsePreview,
                                sessionHeaders,
                            )
                            if (fallback.isNotEmpty()) {
                                Log.i(
                                    TAG,
                                    "Doujindesu fallback parser OK count=${fallback.size}",
                                )
                                result.success(
                                    mapOf(
                                        "source" to source.toMap(),
                                        "hasNextPage" to (fallback.size >= 24),
                                        "mangas" to fallback,
                                    ),
                                )
                                return@use
                            }
                        }
                        throw parseError
                    }
                    val mangas = parsed.callOrNull("getMangas") as? List<*> ?: constEmptyList
                    val hasNextPage = parsed.callOrNull("getHasNextPage") as? Boolean ?: false
                    Log.i(
                        TAG,
                        "fetchMangaPage OK mode=$mode ${source.packageName} count=${mangas.size} next=$hasNextPage",
                    )
                    result.success(
                        mapOf(
                            "source" to source.toMap(),
                            "hasNextPage" to hasNextPage,
                            "mangas" to mangas.mapNotNull {
                                it?.toMangaMap(source.instance, sessionHeaders)
                            },
                        ),
                    )
                }
            } catch (e: Throwable) {
                Log.e(TAG, "fetchMangaPage failed mode=$mode for $packageName", e)
                result.error("fetch_failed", e.safeMessage(), e.stackTraceToString())
            }
        }.start()
    }

    private fun fetchMangaDetailsFromExtension(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")
        val mangaUrl = call.argument<String>("mangaUrl")
        if (packageName.isNullOrBlank() || mangaUrl.isNullOrBlank()) {
            result.error("bad_args", "packageName/mangaUrl kosong", null)
            return
        }
        Thread {
            try {
                val source = loadExtensionSource(
                    packageName,
                    call.argument<String>("sourceName"),
                    call.argument<String>("sourceLang"),
                    call.argument<String>("baseUrl"),
                )
                val manga = newManga(call).apply { url = mangaUrl }
                val sessionHeaders = call.sessionHeaders()
                val request = (source.instance.call("mangaDetailsRequest", manga) as Request)
                    .withSessionHeaders(sessionHeaders)
                val client = source.instance.callOrNull("getClient") as? OkHttpClient
                    ?: OkHttpClient()
                client.newCall(request).execute().use { response ->
                    val parsed = source.instance.call("mangaDetailsParse", response)
                        ?: throw IllegalStateException("mangaDetailsParse mengembalikan null")
                    result.success(
                        (parsed as SManga).toMangaMap(source.instance, sessionHeaders),
                    )
                }
            } catch (e: Throwable) {
                Log.e(TAG, "fetchMangaDetails failed for $packageName", e)
                result.error("details_failed", e.safeMessage(), e.stackTraceToString())
            }
        }.start()
    }

    private fun fetchChapterListFromExtension(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")
        val mangaUrl = call.argument<String>("mangaUrl")
        if (packageName.isNullOrBlank() || mangaUrl.isNullOrBlank()) {
            result.error("bad_args", "packageName/mangaUrl kosong", null)
            return
        }
        Thread {
            try {
                val source = loadExtensionSource(
                    packageName,
                    call.argument<String>("sourceName"),
                    call.argument<String>("sourceLang"),
                    call.argument<String>("baseUrl"),
                )
                val manga = newManga(call).apply { url = mangaUrl }
                val request = (source.instance.call("chapterListRequest", manga) as Request)
                    .withSessionHeaders(call.sessionHeaders())
                val client = source.instance.callOrNull("getClient") as? OkHttpClient
                    ?: OkHttpClient()
                client.newCall(request).execute().use { response ->
                    val chapters = source.instance.call("chapterListParse", response) as? List<*>
                        ?: constEmptyList
                    result.success(chapters.mapNotNull { it?.toChapterMap() })
                }
            } catch (e: Throwable) {
                Log.e(TAG, "fetchChapterList failed for $packageName", e)
                result.error("chapters_failed", e.safeMessage(), e.stackTraceToString())
            }
        }.start()
    }

    private fun fetchPageListFromExtension(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")
        val chapterUrl = call.argument<String>("chapterUrl")
        if (packageName.isNullOrBlank() || chapterUrl.isNullOrBlank()) {
            result.error("bad_args", "packageName/chapterUrl kosong", null)
            return
        }
        Thread {
            try {
                val source = loadExtensionSource(
                    packageName,
                    call.argument<String>("sourceName"),
                    call.argument<String>("sourceLang"),
                    call.argument<String>("baseUrl"),
                )
                val chapter = SChapter.create().apply {
                    url = chapterUrl
                    name = call.argument<String>("chapterName") ?: ""
                }
                val sessionHeaders = call.sessionHeaders()
                val request = (source.instance.call("pageListRequest", chapter) as Request)
                    .withSessionHeaders(sessionHeaders)
                val client = source.instance.callOrNull("getClient") as? OkHttpClient
                    ?: OkHttpClient()
                client.newCall(request).execute().use { response ->
                    val pages = source.instance.call("pageListParse", response) as? List<*>
                        ?: constEmptyList
                    val mappedPages = pages.mapNotNull {
                        it?.toPageMap(source.instance, client, sessionHeaders)
                    }
                    Log.i(
                        TAG,
                        "fetchPageList OK ${source.packageName} count=${mappedPages.size}",
                    )
                    result.success(mappedPages)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "fetchPageList failed for $packageName", e)
                result.error("pages_failed", e.safeMessage(), e.stackTraceToString())
            }
        }.start()
    }

    private fun loadExtensionSource(
        packageName: String,
        sourceName: String? = null,
        sourceLang: String? = null,
        baseUrl: String? = null,
    ): LoadedExtensionSource {
        val sources = loadAllExtensionSources(packageName)
        if (sources.isEmpty()) {
            throw IllegalStateException("Extension $packageName tidak memiliki source")
        }

        fun normalized(value: String?): String = value.orEmpty().trim().lowercase()
        fun host(value: String?): String = runCatching {
            Uri.parse(value.orEmpty()).host.orEmpty().lowercase()
        }.getOrDefault("")
        val wantedName = normalized(sourceName)
        val wantedLang = normalized(sourceLang)
        val wantedHost = host(baseUrl)

        return sources.firstOrNull { source ->
            val name = normalized(source.instance.callOrNull("getName") as? String)
            val lang = normalized(source.instance.callOrNull("getLang") as? String)
            val sourceHost = host(source.instance.callOrNull("getBaseUrl") as? String)
            (wantedName.isEmpty() || name == wantedName) &&
                (wantedLang.isEmpty() || lang == wantedLang) &&
                (wantedHost.isEmpty() || sourceHost == wantedHost)
        } ?: sources.firstOrNull { source ->
            val name = normalized(source.instance.callOrNull("getName") as? String)
            val lang = normalized(source.instance.callOrNull("getLang") as? String)
            (wantedName.isEmpty() || name == wantedName) &&
                (wantedLang.isEmpty() || lang == wantedLang)
        } ?: sources.firstOrNull { source ->
            host(source.instance.callOrNull("getBaseUrl") as? String) == wantedHost
        } ?: sources.first()
    }

    private fun loadAllExtensionSources(packageName: String): List<LoadedExtensionSource> =
        synchronized(sourceCacheLock) {
        val packageManager = context.packageManager
        val appInfo = packageManager.applicationInfoWithMetaData(packageName)
        val sourceDir = appInfo.sourceDir
            ?: throw IllegalStateException("APK path tidak ditemukan untuk $packageName")
        sourceCache[packageName]
            ?.takeIf { cached -> cached.firstOrNull()?.sourceDir == sourceDir }
            ?.let { return@synchronized it }
        val rawClassName = extensionClassName(appInfo)
            ?: throw IllegalStateException("tachiyomi.extension.class tidak ditemukan")
        val className = rawClassName.normalizeClassName(packageName)
        val optimizedDir = context.codeCacheDir.resolve("extension-dex").apply { mkdirs() }
        val classLoader = DexClassLoader(
            sourceDir,
            optimizedDir.absolutePath,
            appInfo.nativeLibraryDir,
            javaClass.classLoader,
        )
        val root = classLoader.loadClass(className).getDeclaredConstructor()
            .apply { isAccessible = true }
            .newInstance()
        val instances = if (
            root.findMethod("popularMangaRequest", 1) != null ||
            root.findMethod("searchMangaRequest", 3) != null
        ) {
            listOf(root)
        } else {
            (root.call("createSources") as? List<*>)?.filterNotNull()
                ?: throw IllegalStateException("SourceFactory tidak mengembalikan List")
        }
        val loaded = instances.map { instance ->
            LoadedExtensionSource(
                packageName = packageName,
                sourceDir = sourceDir,
                extensionClass = instance.javaClass.name,
                instance = instance,
            )
        }
        sourceCache[packageName] = loaded
        loaded
    }

    private fun installedPackages(packageManager: PackageManager): List<PackageInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getInstalledPackages(
                PackageManager.PackageInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getInstalledPackages(PackageManager.GET_META_DATA)
        }

    private fun PackageManager.applicationInfoWithMetaData(packageName: String): ApplicationInfo =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getApplicationInfo(
                packageName,
                PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        }

    private fun PackageInfo.longVersionCodeCompat(): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) longVersionCode
        else {
            @Suppress("DEPRECATION")
            versionCode.toLong()
        }

    private fun String.isTachiyomiExtensionPackage(): Boolean =
        startsWith("eu.kanade.tachiyomi.extension.") ||
            startsWith("app.mihon.extension.") ||
            startsWith("tachiyomi.extension.")

    private fun extensionClassName(appInfo: ApplicationInfo?): String? =
        appInfo?.metaData?.getString("tachiyomi.extension.class")

    private fun String.normalizeClassName(packageName: String): String =
        if (startsWith(".")) "$packageName$this" else this

    private fun Any.call(name: String, vararg args: Any?): Any? {
        val method = findMethod(name, args.size)
            ?: throw NoSuchMethodException("${javaClass.name}.$name/${args.size}")
        method.isAccessible = true
        return method.invoke(this, *args)
    }

    private fun Any.findMethod(name: String, parameterCount: Int): java.lang.reflect.Method? {
        var cursor: Class<*>? = javaClass
        while (cursor != null) {
            cursor.declaredMethods.firstOrNull { method ->
                method.name == name && method.parameterTypes.size == parameterCount
            }?.let { return it }
            cursor = cursor.superclass
        }
        return javaClass.methods.firstOrNull { method ->
            method.name == name && method.parameterTypes.size == parameterCount
        }
    }

    private fun Any.callOrNull(name: String, vararg args: Any?): Any? =
        runCatching { call(name, *args) }.getOrNull()

    private fun Throwable.safeMessage(): String =
        cause?.message ?: message ?: javaClass.simpleName

    private fun MethodCall.sessionHeaders(): Map<String, String> {
        val raw = argument<Map<*, *>>("sessionHeaders") ?: return emptyMap()
        return raw.entries.mapNotNull { (key, value) ->
            val name = key?.toString()?.trim().orEmpty()
            val content = value?.toString()?.trim().orEmpty()
            if (name.isEmpty() || content.isEmpty()) null else name to content
        }.toMap()
    }

    private fun Request.withSessionHeaders(sessionHeaders: Map<String, String>): Request {
        if (sessionHeaders.isEmpty()) return this
        val builder = newBuilder()
        sessionHeaders.forEach { (name, value) ->
            if (name.equals("Cookie", ignoreCase = true)) {
                val existing = header("Cookie")
                builder.header(name, listOfNotNull(existing, value).joinToString("; "))
            } else {
                builder.header(name, value)
            }
        }
        return builder.build()
    }

    private fun newManga(call: MethodCall): SManga =
        SManga.create().apply {
            url = call.argument<String>("mangaUrl") ?: ""
            title = call.argument<String>("title") ?: ""
            thumbnail_url = call.argument<String>("thumbnailUrl")
        }

    private fun Any.toMangaMap(
        sourceInstance: Any? = null,
        sessionHeaders: Map<String, String> = emptyMap(),
    ): Map<String, Any?> = mapOf(
        "title" to (callOrNull("getTitle") as? String ?: ""),
        "url" to (callOrNull("getUrl") as? String ?: ""),
        "thumbnailUrl" to firstString("getThumbnail_url", "getThumbnailUrl"),
        "headers" to buildMap {
            putAll((sourceInstance?.callOrNull("getHeaders") as? Headers)?.toMap().orEmpty())
            putAll(sessionHeaders)
        },
        "author" to callOrNull("getAuthor") as? String,
        "artist" to callOrNull("getArtist") as? String,
        "description" to callOrNull("getDescription") as? String,
        "genre" to callOrNull("getGenre") as? String,
        "status" to (callOrNull("getStatus") as? Int ?: 0),
    )

    private fun Any.firstString(vararg names: String): String? =
        names.asSequence()
            .mapNotNull { callOrNull(it) as? String }
            .firstOrNull { it.isNotBlank() }

    private fun parseDoujindesuMangas(
        body: String,
        headers: Map<String, String> = emptyMap(),
    ): List<Map<String, Any?>> {
        val items = runCatching { JSONArray(body) }.getOrNull() ?: return emptyList()
        return buildList {
            for (index in 0 until items.length()) {
                val item = items.optJSONObject(index) ?: continue
                val slug = item.optString("slug").trim()
                val title = item.optString("title").trim()
                if (slug.isEmpty() || title.isEmpty()) continue
                val status = when (item.optString("status").lowercase()) {
                    "ongoing", "publishing" -> SManga.ONGOING
                    "completed" -> SManga.COMPLETED
                    else -> SManga.UNKNOWN
                }
                add(
                    mapOf(
                        "title" to title,
                        "url" to "/manga/$slug/",
                        "thumbnailUrl" to item.optString("cover_url").ifBlank { null },
                        "headers" to headers,
                        "author" to item.optString("author").ifBlank { null },
                        "artist" to null,
                        "description" to item.optString("description").ifBlank { null },
                        "genre" to null,
                        "status" to status,
                    ),
                )
            }
        }
    }

    private fun Any.toChapterMap(): Map<String, Any?> = mapOf(
        "url" to (callOrNull("getUrl") as? String ?: ""),
        "name" to (callOrNull("getName") as? String ?: ""),
        "dateUpload" to (callOrNull("getDate_upload") as? Long ?: 0L),
        "chapterNumber" to (callOrNull("getChapter_number") as? Float ?: -1f),
        "scanlator" to callOrNull("getScanlator") as? String,
    )

    private fun Any.toPageMap(
        sourceInstance: Any,
        client: OkHttpClient,
        sessionHeaders: Map<String, String>,
    ): Map<String, Any?> {
        val url = callOrNull("getUrl") as? String ?: ""
        var finalImageUrl = callOrNull("getImageUrl") as? String
        var requestHeaders = emptyMap<String, String>()
        val imageRequest = runCatching {
            (sourceInstance.call("imageRequest", this) as Request)
                .withSessionHeaders(sessionHeaders)
        }.getOrNull()
        if (imageRequest != null) {
            requestHeaders = buildMap {
                putAll(imageRequest.headers.toMap())
                putAll(sessionHeaders)
            }
            if (finalImageUrl.isNullOrBlank()) {
                finalImageUrl = runCatching {
                    client.newCall(imageRequest).execute().use { response ->
                        sourceInstance.call("imageUrlParse", response) as? String
                    }
                }.getOrNull()
            }
            if (finalImageUrl.isNullOrBlank()) {
                finalImageUrl = imageRequest.url.toString()
            }
        }
        return mapOf(
            "index" to (callOrNull("getIndex") as? Int ?: 0),
            "url" to url,
            "imageUrl" to finalImageUrl,
            "headers" to requestHeaders,
        )
    }

    private inner class LoadedExtensionSource(
        val packageName: String,
        val sourceDir: String,
        val extensionClass: String,
        val instance: Any,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "packageName" to packageName,
            "sourceDir" to sourceDir,
            "extensionClass" to extensionClass,
            "className" to instance.javaClass.name,
            "name" to (instance.callOrNull("getName") as? String ?: ""),
            "baseUrl" to (instance.callOrNull("getBaseUrl") as? String ?: ""),
            "lang" to (instance.callOrNull("getLang") as? String ?: ""),
            "id" to (instance.callOrNull("getId") as? Long ?: 0L),
            "supportsLatest" to (instance.callOrNull("getSupportsLatest") as? Boolean ?: false),
            "superclasses" to buildList {
                var cursor: Class<*>? = instance.javaClass
                while (cursor != null) {
                    add(cursor.name)
                    cursor = cursor.superclass
                }
            },
        )
    }

    companion object {
        private const val CHANNEL = "kizen/extension_runtime"
        private const val TAG = "KizenExtensionRuntime"
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
        private const val API_VERSION = 1
        private val constEmptyList = emptyList<Any?>()
    }
}
