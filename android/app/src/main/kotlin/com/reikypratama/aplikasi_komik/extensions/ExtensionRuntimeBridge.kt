package com.reikypratama.aplikasi_komik.extensions

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.webkit.CookieManager
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.content.FileProvider
import androidx.core.net.toUri
import dalvik.system.DexClassLoader
import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import java.io.File
import java.net.InetAddress
import okhttp3.Dns
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Headers
import org.json.JSONArray
import org.json.JSONObject
import org.jsoup.Jsoup
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
        instance = this
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "runtimeInfo" -> result.success(runtimeInfo())
            "openVpnSettings" -> openVpnSettings(result)
            "openPrivateDnsSettings" -> openPrivateDnsSettings(result)
            "setVpnEnabled" -> setVpnEnabled(call, result)
            "getVpnStatus" -> getVpnStatus(result)
            "probeUrl" -> probeUrl(call, result)
            "readWebViewSession" -> readWebViewSession(call, result)
            "renderHtmlWithWebView" -> renderHtmlWithWebView(call, result)
            "listInstalledExtensions" -> result.success(listInstalledExtensions())
            "prepareExtensionApk" -> prepareExtensionApk(call, result)
            "installExtensionApk" -> installExtensionApk(call, result)
            "downloadAndInstallAppUpdate" -> downloadAndInstallAppUpdate(call, result)
            "cancelUpdateDownload" -> cancelUpdateDownload(result)
            "openDownloadedUpdateInstaller" -> openDownloadedUpdateInstaller(call, result)
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

    @Volatile
    private var vpnEnabled = true

    @Volatile
    private var vpnProvider = "cloudflare"

    private fun setVpnEnabled(call: MethodCall, result: MethodChannel.Result) {
        vpnEnabled = call.argument<Boolean>("enabled") ?: true
        vpnProvider = call.argument<String>("provider") ?: "cloudflare"
        Log.i(TAG, "VPN/DoH status changed: enabled=$vpnEnabled, provider=$vpnProvider")
        val activity = context as? com.reikypratama.aplikasi_komik.MainActivity
        if (activity != null) {
            if (vpnEnabled) {
                activity.startVpnWithPermission(vpnProvider, result)
            } else {
                activity.stopVpn(result)
            }
        } else {
            result.success(true)
        }
    }

    private fun getVpnStatus(result: MethodChannel.Result) {
        val running = com.reikypratama.aplikasi_komik.vpn.KizenVpnService.isRunning
        result.success(
            mapOf(
                "enabled" to running,
                "isRunning" to running,
                "provider" to vpnProvider,
            )
        )
    }

    private fun openPrivateDnsSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Throwable) {
            openVpnSettings(result)
        }
    }

    private fun applyVpnDns(client: OkHttpClient): OkHttpClient {
        if (!vpnEnabled) return client
        return try {
            client.newBuilder()
                .dns(DohDns(vpnProvider))
                .build()
        } catch (e: Throwable) {
            Log.w(TAG, "applyVpnDns error: ${e.message}")
            client
        }
    }

    private fun openVpnSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_VPN_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Throwable) {
            try {
                val fallback = Intent(Settings.ACTION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(fallback)
                result.success(true)
            } catch (fallbackError: Throwable) {
                result.error(
                    "settings_failed",
                    fallbackError.safeMessage(),
                    fallbackError.stackTraceToString(),
                )
            }
        }
    }

    private fun probeUrl(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.error("bad_args", "url kosong", null)
            return
        }
        Thread {
            try {
                val request = Request.Builder()
                    .url(url)
                    .header(
                        "User-Agent",
                        WebSettings.getDefaultUserAgent(context),
                    )
                    .get()
                    .build()
                val client = applyVpnDns(
                    OkHttpClient.Builder()
                        .followRedirects(true)
                        .followSslRedirects(true)
                        .build()
                )
                client.newCall(request)
                    .execute()
                    .use { response ->
                        val preview = response.peekBody(64L * 1024L).string()
                        result.success(
                            mapOf(
                                "ok" to response.isSuccessful,
                                "statusCode" to response.code,
                                "finalUrl" to response.request.url.toString(),
                                "blocked" to preview.looksLikeNetworkBlock(),
                                "message" to response.message,
                            ),
                        )
                    }
            } catch (e: Throwable) {
                val message = e.safeMessage()
                result.success(
                    mapOf(
                        "ok" to false,
                        "statusCode" to 0,
                        "finalUrl" to url,
                        "blocked" to message.looksLikeNetworkBlock(),
                        "message" to message,
                    ),
                )
            }
        }.start()
    }

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

    @SuppressLint("SetJavaScriptEnabled")
    private fun renderHtmlWithWebView(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.error("bad_args", "url kosong", null)
            return
        }
        val lower = url.trim().lowercase()
        if (!lower.startsWith("http://") && !lower.startsWith("https://")) {
            result.error("bad_args", "Hanya URL http/https yang diizinkan: $url", null)
            return
        }
        Handler(Looper.getMainLooper()).post {
            var completed = false
            lateinit var webView: WebView
            val handler = Handler(Looper.getMainLooper())
            fun finishSuccess(html: String?) {
                if (completed) return
                completed = true
                runCatching {
                    webView.stopLoading()
                    webView.destroy()
                }
                result.success(html.orEmpty())
            }
            fun finishError(error: Throwable) {
                if (completed) return
                completed = true
                runCatching {
                    webView.stopLoading()
                    webView.destroy()
                }
                result.error("webview_render_failed", error.safeMessage(), error.stackTraceToString())
            }
            fun captureHtml() {
                if (completed) return
                webView.evaluateJavascript(
                    WEBVIEW_RENDER_SCRIPT,
                ) { encoded ->
                    val html = runCatching { JSONArray("[$encoded]").optString(0) }
                        .getOrDefault("")
                    finishSuccess(html)
                }
            }

            try {
                val sessionHeaders = call.sessionHeaders()
                val cookie = sessionHeaders.entries.firstOrNull {
                    it.key.equals("Cookie", ignoreCase = true)
                }?.value
                val manager = CookieManager.getInstance()
                manager.setAcceptCookie(true)
                if (!cookie.isNullOrBlank()) {
                    cookie.split(';')
                        .map { it.trim() }
                        .filter { it.isNotEmpty() }
                        .forEach { manager.setCookie(url, it) }
                    manager.flush()
                }

                webView = WebView(context)
                manager.setAcceptThirdPartyCookies(webView, true)
                webView.settings.apply {
                    // Snapshot DOM memang perlu JavaScript. WebView ini tidak
                    // mengekspos JavascriptInterface dan gambar diblokir.
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    allowFileAccess = false
                    allowContentAccess = false
                    loadsImagesAutomatically = false
                    blockNetworkImage = true
                    userAgentString = sessionHeaders.entries.firstOrNull {
                        it.key.equals("User-Agent", ignoreCase = true)
                    }?.value ?: WebSettings.getDefaultUserAgent(context)
                    mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                }
                webView.webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView, finishedUrl: String) {
                        handler.postDelayed({ captureHtml() }, WEBVIEW_RENDER_SETTLE_MS)
                    }
                }
                handler.postDelayed({ captureHtml() }, WEBVIEW_RENDER_TIMEOUT_MS)
                webView.loadUrl(
                    url,
                    sessionHeaders.filterKeys { !it.equals("Cookie", ignoreCase = true) },
                )
            } catch (e: Throwable) {
                finishError(e)
            }
        }
    }

    private fun prepareExtensionApk(call: MethodCall, result: MethodChannel.Result) {
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
                if (!apkFile.exists() || apkFile.length() == 0L) {
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
                }
                Handler(Looper.getMainLooper()).post {
                    result.success(true)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "prepareExtensionApk failed for $apkUrl", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("prepare_failed", e.safeMessage(), e.stackTraceToString())
                }
            }
        }.start()
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
                if (!apkFile.exists() || apkFile.length() == 0L) {
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
                Handler(Looper.getMainLooper()).post {
                    result.success(null)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "installExtensionApk failed for $apkUrl", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("install_failed", e.safeMessage(), e.stackTraceToString())
                }
            }
        }.start()
    }

    @Volatile
    private var updateDownloadCall: okhttp3.Call? = null

    private fun cancelUpdateDownload(result: MethodChannel.Result) {
        try {
            updateDownloadCall?.cancel()
            updateDownloadCall = null
            result.success(true)
        } catch (e: Throwable) {
            result.error("cancel_failed", e.safeMessage(), null)
        }
    }

    private fun openDownloadedUpdateInstaller(call: MethodCall, result: MethodChannel.Result) {
        val rawFileName = call.argument<String>("fileName") ?: "kizen-update.apk"
        val fileName = rawFileName
            .substringAfterLast('/')
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .takeIf { it.endsWith(".apk", ignoreCase = true) }
            ?: "kizen-update.apk"
        val dir = File(context.cacheDir, "app-updates")
        val apkFile = File(dir, fileName)
        if (!apkFile.exists() || apkFile.length() == 0L) {
            result.error("not_found", "File APK update belum diunduh", null)
            return
        }
        try {
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
            Log.i(TAG, "openDownloadedUpdateInstaller opened installer for $fileName")
            result.success(true)
        } catch (e: Throwable) {
            Log.e(TAG, "openDownloadedUpdateInstaller failed for $fileName", e)
            result.error("install_failed", e.safeMessage(), e.stackTraceToString())
        }
    }

    private fun downloadAndInstallAppUpdate(call: MethodCall, result: MethodChannel.Result) {
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
                    ?: "kizen-update.apk"
                val dir = File(context.cacheDir, "app-updates").apply { mkdirs() }
                val apkFile = File(dir, fileName)
                if (apkFile.exists()) {
                    apkFile.delete()
                }

                val request = Request.Builder()
                    .url(apkUrl)
                    .header(
                        "User-Agent",
                        "Kizen-Android-App",
                    )
                    .get()
                    .build()

                val client = OkHttpClient.Builder()
                    .followRedirects(true)
                    .followSslRedirects(true)
                    .build()

                val okCall = client.newCall(request)
                updateDownloadCall = okCall

                okCall.execute().use { response ->
                    if (!response.isSuccessful) {
                        throw IllegalStateException("Download APK gagal: HTTP ${response.code}")
                    }
                    val body = response.body ?: throw IllegalStateException("Response body kosong")
                    val totalBytes = body.contentLength()
                    var receivedBytes = 0L

                    val buffer = ByteArray(8192)
                    var lastProgressUpdate = 0L

                    apkFile.outputStream().use { output ->
                        val inputStream = body.byteStream()
                        var read: Int
                        while (inputStream.read(buffer).also { read = it } != -1) {
                            output.write(buffer, 0, read)
                            receivedBytes += read

                            val now = System.currentTimeMillis()
                            if (now - lastProgressUpdate > 100 || receivedBytes == totalBytes) {
                                lastProgressUpdate = now
                                Handler(Looper.getMainLooper()).post {
                                    channel.invokeMethod(
                                        "onUpdateDownloadProgress",
                                        mapOf(
                                            "received" to receivedBytes,
                                            "total" to totalBytes,
                                            "completed" to false,
                                        ),
                                    )
                                }
                            }
                        }
                        output.flush()
                    }
                }
                updateDownloadCall = null

                Handler(Looper.getMainLooper()).post {
                    channel.invokeMethod(
                        "onUpdateDownloadProgress",
                        mapOf(
                            "received" to apkFile.length(),
                            "total" to apkFile.length(),
                            "completed" to true,
                        ),
                    )
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
                Log.i(TAG, "downloadAndInstallAppUpdate opened installer for $fileName")
                Handler(Looper.getMainLooper()).post {
                    result.success(true)
                }
            } catch (e: Throwable) {
                updateDownloadCall = null
                Log.e(TAG, "downloadAndInstallAppUpdate failed for $apkUrl", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("download_failed", e.safeMessage(), e.stackTraceToString())
                }
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
                data = "package:$packageName".toUri()
                putExtra(Intent.EXTRA_RETURN_RESULT, true)
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
        Thread {
            try {
                val source = loadExtensionSource(packageName)
                val sourceMap = source.toMap()
                Log.i(TAG, "inspectExtension OK ${source.packageName} -> ${sourceMap["name"]}")
                result.success(sourceMap)
            } catch (e: Throwable) {
                Log.e(TAG, "inspectExtension failed for $packageName", e)
                result.error("inspect_failed", e.safeMessage(), e.stackTraceToString())
            }
        }.start()
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

        val isDoujin = packageName.contains("doujindesu", ignoreCase = true) ||
            call.argument<String>("baseUrl")?.contains("doujin", ignoreCase = true) == true
        val isImhentai = packageName.contains("imhentai", ignoreCase = true) ||
            call.argument<String>("baseUrl")?.contains("imhentai", ignoreCase = true) == true

        Thread {
            val sessionHeaders = call.sessionHeaders()
            try {
                val source = runCatching {
                    loadExtensionSource(
                        packageName,
                        call.argument<String>("sourceName"),
                        call.argument<String>("sourceLang"),
                        call.argument<String>("baseUrl"),
                    )
                }.getOrNull()

                if (source == null && isDoujin) {
                    val fallback = runCatching {
                        fetchDoujindesuCatalogDirect(mode, query, page, sessionHeaders)
                    }.getOrDefault(emptyList())
                    if (fallback.isNotEmpty()) {
                        Log.i(TAG, "Doujindesu direct catalog OK count=${fallback.size}")
                        result.success(
                            mapOf(
                                "source" to mapOf(
                                    "packageName" to packageName,
                                    "sourceDir" to "",
                                    "extensionClass" to "DoujindesuNative",
                                    "className" to "DoujindesuNative",
                                ),
                                "hasNextPage" to (fallback.size >= 24),
                                "mangas" to fallback,
                            ),
                        )
                        return@Thread
                    }
                }

                if (source == null && isImhentai) {
                    val fallback = runCatching {
                        fetchImhentaiCatalogDirect(mode, query, page, sessionHeaders)
                    }.getOrDefault(emptyList())
                    if (fallback.isNotEmpty()) {
                        Log.i(TAG, "IMHentai direct catalog OK count=${fallback.size}")
                        result.success(
                            mapOf(
                                "source" to mapOf(
                                    "packageName" to packageName,
                                    "sourceDir" to "",
                                    "extensionClass" to "IMHentaiNative",
                                    "className" to "IMHentaiNative",
                                ),
                                "hasNextPage" to (fallback.size >= 20),
                                "mangas" to fallback,
                            ),
                        )
                        return@Thread
                    }
                }

                if (source == null) {
                    throw IllegalStateException("Ekstensi $packageName belum terpasang di perangkat")
                }

                val parsed = runCatching {
                    // Coba panggil suspend function resmi Tachiyomi/Mihon terlebih dahulu
                    val suspendMethod = when (mode) {
                        "latest" -> "getLatestUpdates"
                        "search" -> "getSearchManga"
                        else -> "getPopularManga"
                    }
                    val suspendRes = if (mode == "search") {
                        val filterList = source.instance.callOrNull("getFilterList") as? FilterList ?: FilterList()
                        invokeSuspend(source.instance, suspendMethod, page, query, filterList)
                    } else {
                        invokeSuspend(source.instance, suspendMethod, page)
                    }
                    if (suspendRes != null) {
                        return@runCatching suspendRes
                    }

                    // Fallback cara lama (popularMangaRequest + execute + popularMangaParse)
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
                    val baseClient = source.instance.callOrNull("getClient") as? OkHttpClient
                        ?: OkHttpClient()
                    val client = applyVpnDns(baseClient)
                    client.newCall(request).execute().use { response ->
                        val parseMethod = when (mode) {
                            "latest" -> "latestUpdatesParse"
                            "search" -> "searchMangaParse"
                            else -> "popularMangaParse"
                        }
                        source.instance.call(parseMethod, response)
                            ?: throw IllegalStateException("$parseMethod mengembalikan null")
                    }
                }.getOrElse { parseError ->
                    if (isDoujin) {
                        val fallback = runCatching {
                            fetchDoujindesuCatalogDirect(mode, query, page, sessionHeaders)
                        }.getOrDefault(emptyList())

                        if (fallback.isNotEmpty()) {
                            Log.i(TAG, "Doujindesu fallback parser OK count=${fallback.size}")
                            result.success(
                                mapOf(
                                    "source" to source.toMap(),
                                    "hasNextPage" to (fallback.size >= 24),
                                    "mangas" to fallback,
                                ),
                            )
                            return@Thread
                        }
                    }
                    if (isImhentai) {
                        val fallback = runCatching {
                            fetchImhentaiCatalogDirect(mode, query, page, sessionHeaders)
                        }.getOrDefault(emptyList())

                        if (fallback.isNotEmpty()) {
                            Log.i(TAG, "IMHentai fallback parser OK count=${fallback.size}")
                            result.success(
                                mapOf(
                                    "source" to source.toMap(),
                                    "hasNextPage" to (fallback.size >= 20),
                                    "mangas" to fallback,
                                ),
                            )
                            return@Thread
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
            } catch (e: Throwable) {
                if (isDoujin) {
                    val fallback = runCatching {
                        fetchDoujindesuCatalogDirect(mode, query, page, sessionHeaders)
                    }.getOrDefault(emptyList())
                    if (fallback.isNotEmpty()) {
                        Log.i(TAG, "Doujindesu direct catalog catch-fallback OK count=${fallback.size}")
                        result.success(
                            mapOf(
                                "source" to mapOf(
                                    "packageName" to packageName,
                                    "sourceDir" to "",
                                    "extensionClass" to "DoujindesuNative",
                                    "className" to "DoujindesuNative",
                                ),
                                "hasNextPage" to (fallback.size >= 24),
                                "mangas" to fallback,
                            ),
                        )
                        return@Thread
                    }
                }
                if (isImhentai) {
                    val fallback = runCatching {
                        fetchImhentaiCatalogDirect(mode, query, page, sessionHeaders)
                    }.getOrDefault(emptyList())
                    if (fallback.isNotEmpty()) {
                        Log.i(TAG, "IMHentai direct catalog catch-fallback OK count=${fallback.size}")
                        result.success(
                            mapOf(
                                "source" to mapOf(
                                    "packageName" to packageName,
                                    "sourceDir" to "",
                                    "extensionClass" to "IMHentaiNative",
                                    "className" to "IMHentaiNative",
                                ),
                                "hasNextPage" to (fallback.size >= 20),
                                "mangas" to fallback,
                            ),
                        )
                        return@Thread
                    }
                }
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
        val isDoujin = packageName.contains("doujindesu", ignoreCase = true) ||
            mangaUrl.contains("doujin", ignoreCase = true) ||
            call.argument<String>("baseUrl")?.contains("doujin", ignoreCase = true) == true
        val isImhentai = packageName.contains("imhentai", ignoreCase = true) ||
            mangaUrl.contains("imhentai", ignoreCase = true) ||
            call.argument<String>("baseUrl")?.contains("imhentai", ignoreCase = true) == true

        Thread {
            val sessionHeaders = call.sessionHeaders()
            try {
                val source = runCatching {
                    loadExtensionSource(
                        packageName,
                        call.argument<String>("sourceName"),
                        call.argument<String>("sourceLang"),
                        call.argument<String>("baseUrl"),
                    )
                }.getOrNull()

                if (source == null && isDoujin) {
                    val direct = fetchDoujindesuDetailsDirect(mangaUrl, sessionHeaders)
                    result.success(direct)
                    return@Thread
                }
                if (source == null && isImhentai) {
                    val direct = fetchImhentaiDetailsDirect(mangaUrl, sessionHeaders)
                    result.success(direct)
                    return@Thread
                }
                if (source == null) {
                    throw IllegalStateException("Ekstensi $packageName belum terpasang di perangkat")
                }

                val manga = newManga(call).apply { url = mangaUrl }
                val parsed = runCatching {
                    invokeSuspend(source.instance, "getMangaDetails", manga) as? SManga
                }.getOrNull() ?: runCatching {
                    val update = invokeSuspend(
                        source.instance,
                        "getMangaUpdate",
                        manga,
                        emptyList<SChapter>(),
                        true,
                        false,
                    )
                    update?.callOrNull("getManga") as? SManga
                }.getOrNull() ?: runCatching {
                    val update = invokeSuspend(
                        source.instance,
                        "getMangaUpdate",
                        manga,
                        emptyList<SChapter>(),
                        true,
                        true,
                    )
                    update?.callOrNull("getManga") as? SManga
                }.getOrNull() ?: run {
                    val request = (source.instance.call("mangaDetailsRequest", manga) as Request)
                        .withSessionHeaders(sessionHeaders)
                    val baseClient = source.instance.callOrNull("getClient") as? OkHttpClient
                        ?: OkHttpClient()
                    val client = applyVpnDns(baseClient)
                    client.newCall(request).execute().use { response ->
                        source.instance.call("mangaDetailsParse", response) as SManga
                    }
                }
                result.success(
                    parsed.toMangaMap(source.instance, sessionHeaders),
                )
            } catch (e: Throwable) {
                if (isDoujin) {
                    val direct = runCatching {
                        fetchDoujindesuDetailsDirect(mangaUrl, sessionHeaders)
                    }.getOrNull()
                    if (direct != null) {
                        Log.i(TAG, "Doujindesu direct details fallback OK")
                        result.success(direct)
                        return@Thread
                    }
                }
                if (isImhentai) {
                    val direct = runCatching {
                        fetchImhentaiDetailsDirect(mangaUrl, sessionHeaders)
                    }.getOrNull()
                    if (direct != null) {
                        Log.i(TAG, "IMHentai direct details fallback OK")
                        result.success(direct)
                        return@Thread
                    }
                }
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
        val isDoujin = packageName.contains("doujindesu", ignoreCase = true) ||
            mangaUrl.contains("doujin", ignoreCase = true) ||
            call.argument<String>("baseUrl")?.contains("doujin", ignoreCase = true) == true
        val isImhentai = packageName.contains("imhentai", ignoreCase = true) ||
            mangaUrl.contains("imhentai", ignoreCase = true) ||
            call.argument<String>("baseUrl")?.contains("imhentai", ignoreCase = true) == true

        Thread {
            val sessionHeaders = call.sessionHeaders()
            try {
                val source = runCatching {
                    loadExtensionSource(
                        packageName,
                        call.argument<String>("sourceName"),
                        call.argument<String>("sourceLang"),
                        call.argument<String>("baseUrl"),
                    )
                }.getOrNull()

                if (source == null && isDoujin) {
                    val direct = fetchDoujindesuChaptersDirect(mangaUrl)
                    result.success(direct)
                    return@Thread
                }
                if (source == null && isImhentai) {
                    val direct = fetchImhentaiChaptersDirect(mangaUrl, sessionHeaders)
                    result.success(direct)
                    return@Thread
                }
                if (source == null) {
                    throw IllegalStateException("Ekstensi $packageName belum terpasang di perangkat")
                }

                val manga = newManga(call).apply { url = mangaUrl }
                val chapters = runCatching {
                    invokeSuspend(source.instance, "getChapterList", manga) as? List<*>
                }.getOrNull() ?: runCatching {
                    val update = invokeSuspend(
                        source.instance,
                        "getMangaUpdate",
                        manga,
                        emptyList<SChapter>(),
                        false,
                        true,
                    )
                    update?.callOrNull("getChapters") as? List<*>
                }.getOrNull() ?: runCatching {
                    val update = invokeSuspend(
                        source.instance,
                        "getMangaUpdate",
                        manga,
                        emptyList<SChapter>(),
                        true,
                        true,
                    )
                    update?.callOrNull("getChapters") as? List<*>
                }.getOrNull() ?: run {
                    val request = (source.instance.call("chapterListRequest", manga) as Request)
                        .withSessionHeaders(call.sessionHeaders())
                    val baseClient = source.instance.callOrNull("getClient") as? OkHttpClient
                        ?: OkHttpClient()
                    val client = applyVpnDns(baseClient)
                    client.newCall(request).execute().use { response ->
                        source.instance.call("chapterListParse", response) as? List<*>
                            ?: constEmptyList
                    }
                }
                result.success(chapters.mapNotNull { it?.toChapterMap() })
            } catch (e: Throwable) {
                if (isDoujin) {
                    val direct = runCatching {
                        fetchDoujindesuChaptersDirect(mangaUrl)
                    }.getOrNull()
                    if (direct != null && direct.isNotEmpty()) {
                        Log.i(TAG, "Doujindesu direct chapters fallback OK count=${direct.size}")
                        result.success(direct)
                        return@Thread
                    }
                }
                if (isImhentai) {
                    val direct = runCatching {
                        fetchImhentaiChaptersDirect(mangaUrl, sessionHeaders)
                    }.getOrNull()
                    if (direct != null && direct.isNotEmpty()) {
                        Log.i(TAG, "IMHentai direct chapters fallback OK count=${direct.size}")
                        result.success(direct)
                        return@Thread
                    }
                }
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
        val isDoujin = packageName.contains("doujindesu", ignoreCase = true) ||
            chapterUrl.contains("doujin", ignoreCase = true) ||
            chapterUrl.contains("/chapter/") ||
            chapterUrl.contains("/api/chapters/") ||
            call.argument<String>("baseUrl")?.contains("doujin", ignoreCase = true) == true
        val isImhentai = packageName.contains("imhentai", ignoreCase = true) ||
            chapterUrl.contains("imhentai", ignoreCase = true) ||
            chapterUrl.contains("/gallery/") ||
            chapterUrl.contains("/view/") ||
            call.argument<String>("baseUrl")?.contains("imhentai", ignoreCase = true) == true

        Thread {
            val sessionHeaders = call.sessionHeaders()
            try {
                val source = runCatching {
                    loadExtensionSource(
                        packageName,
                        call.argument<String>("sourceName"),
                        call.argument<String>("sourceLang"),
                        call.argument<String>("baseUrl"),
                    )
                }.getOrNull()

                if (source == null && isDoujin) {
                    val direct = fetchDoujindesuPagesDirect(chapterUrl, sessionHeaders)
                    result.success(direct)
                    return@Thread
                }
                if (source == null && isImhentai) {
                    val direct = fetchImhentaiPagesDirect(chapterUrl, sessionHeaders)
                    result.success(direct)
                    return@Thread
                }
                if (source == null) {
                    throw IllegalStateException("Ekstensi $packageName belum terpasang di perangkat")
                }

                val chapter = SChapter.create().apply {
                    url = chapterUrl
                    name = call.argument<String>("chapterName") ?: ""
                }
                val baseClient = source.instance.callOrNull("getClient") as? OkHttpClient
                    ?: OkHttpClient()
                val client = applyVpnDns(baseClient)
                val pages = runCatching {
                    invokeSuspend(source.instance, "getPageList", chapter) as? List<*>
                }.getOrNull() ?: run {
                    val request = (source.instance.call("pageListRequest", chapter) as Request)
                        .withSessionHeaders(sessionHeaders)
                    client.newCall(request).execute().use { response ->
                        source.instance.call("pageListParse", response) as? List<*>
                            ?: constEmptyList
                    }
                }
                val mappedPages = pages.mapNotNull {
                    it?.toPageMap(source.instance, client, sessionHeaders)
                }
                Log.i(
                    TAG,
                    "fetchPageList OK ${source.packageName} count=${mappedPages.size}",
                )
                result.success(mappedPages)
            } catch (e: Throwable) {
                Log.e(TAG, "fetchPageList failed for $packageName", e)
                if (isDoujin) {
                    val fallback = runCatching {
                        fetchDoujindesuPagesDirect(chapterUrl, sessionHeaders)
                    }.getOrDefault(emptyList())
                    if (fallback.isNotEmpty()) {
                        Log.i(TAG, "Doujindesu direct pages fallback OK count=${fallback.size}")
                        result.success(fallback)
                        return@Thread
                    }
                }
                if (isImhentai) {
                    val fallback = runCatching {
                        fetchImhentaiPagesDirect(chapterUrl, sessionHeaders)
                    }.getOrDefault(emptyList())
                    if (fallback.isNotEmpty()) {
                        Log.i(TAG, "IMHentai direct pages fallback OK count=${fallback.size}")
                        result.success(fallback)
                        return@Thread
                    }
                }
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
            value.orEmpty().toUri().host.orEmpty().lowercase()
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
            eu.kanade.tachiyomi.source.Source::class.java.isAssignableFrom(root.javaClass) ||
            root.findMethod("popularMangaRequest", 1) != null ||
            root.findMethod("searchMangaRequest", 3) != null ||
            root.findMethod("getPopularManga", 2) != null ||
            root.findMethod("getSearchManga", 4) != null ||
            root.findMethod("getMangaUpdate", 5) != null
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

    private fun invokeSuspend(target: Any, methodName: String, vararg args: Any?): Any? {
        val matchingMethod = target.javaClass.methods.firstOrNull { method ->
            method.name == methodName && method.parameterTypes.size == args.size + 1 &&
                    kotlin.coroutines.Continuation::class.java.isAssignableFrom(
                        method.parameterTypes[args.size]
                    )
        } ?: return null

        val latch = java.util.concurrent.CountDownLatch(1)
        var resultRef: Any? = null
        var errorRef: Throwable? = null

        val continuation = object : kotlin.coroutines.Continuation<Any?> {
            override val context: kotlin.coroutines.CoroutineContext = kotlin.coroutines.EmptyCoroutineContext
            override fun resumeWith(result: Result<Any?>) {
                result.onSuccess { resultRef = it }
                result.onFailure { errorRef = it }
                latch.countDown()
            }
        }

        matchingMethod.isAccessible = true
        val params = arrayOf(*args, continuation)
        val ret = try {
            matchingMethod.invoke(target, *params)
        } catch (e: java.lang.reflect.InvocationTargetException) {
            throw e.targetException ?: e
        }

        if (ret != kotlin.coroutines.intrinsics.COROUTINE_SUSPENDED) {
            return ret
        }

        val completed = latch.await(30, java.util.concurrent.TimeUnit.SECONDS)
        if (!completed) {
            throw java.util.concurrent.TimeoutException("Timeout saat memanggil suspend function $methodName")
        }
        errorRef?.let { throw it }
        return resultRef
    }

    private fun Throwable.safeMessage(): String =
        cause?.message ?: message ?: javaClass.simpleName

    private fun String.looksLikeNetworkBlock(): Boolean {
        val value = lowercase()
        return value.contains("internetbaik") ||
            value.contains("internetpositif") ||
            value.contains("trustpositif") ||
            value.contains("hostname mismatch") ||
            value.contains("certificate_verify_failed")
    }

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

    private fun decryptDoujindesu(encryptedHex: String): String? {
        val salt = "doujindesu-scrapers-cannot-read-this-super-secret-salt-2026-v2"
        val hourMs = 3600000L
        fun toSigned32(x: Long): Int {
            var y = x and 0xFFFFFFFFL
            if (y >= 0x80000000L) y -= 0x100000000L
            return y.toInt()
        }
        fun wH(e: Int): String {
            val t = salt + "_" + e
            var a = 0
            for (ch in t) {
                a = (a shl 5) - a + ch.code
                a = toSigned32(a.toLong())
            }
            var l = if (a != 0) Math.abs(a.toLong()) else 123456789L
            return buildString {
                repeat(32) {
                    l = (l * 1664525L + 1013904223L) % 4294967296L
                    append((33 + (l % 93)).toInt().toChar())
                }
            }
        }
        val now = System.currentTimeMillis()
        val t = (now / hourMs).toInt()
        val keys = listOf(wH(t), wH(t - 1), wH(t + 1))
        for (key in keys) {
            try {
                val bytes = encryptedHex.chunked(2).mapNotNull { it.toIntOrNull(16) }
                var d = 42
                val keyLen = key.length
                val decoded = buildString {
                    for ((idx, byteVal) in bytes.withIndex()) {
                        val keyChar = key[idx % keyLen].code
                        val k = byteVal xor keyChar xor (idx * 13) xor d
                        append((k and 0xFF).toChar())
                        d = (d + byteVal) % 256
                    }
                }
                val unquoted = java.net.URLDecoder.decode(decoded, "UTF-8")
                if (unquoted.startsWith("[") && unquoted.endsWith("]")) {
                    return unquoted
                }
            } catch (_: Throwable) {}
        }
        return null
    }

    private fun parseDoujindesuMangas(
        body: String,
        headers: Map<String, String> = emptyMap(),
    ): List<Map<String, Any?>> {
        var cleanJson = body.trim()
        if (cleanJson.contains("_enc_resp_")) {
            val encHex = runCatching<String> {
                JSONObject(cleanJson).optString("_enc_resp_")
            }.getOrNull()
            if (!encHex.isNullOrBlank()) {
                cleanJson = decryptDoujindesu(encHex) ?: cleanJson
            }
        }
        val items = runCatching { JSONArray(cleanJson) }.getOrNull() ?: return emptyList()
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

    private fun fetchDoujindesuCatalogDirect(
        mode: String,
        query: String,
        page: Int,
        sessionHeaders: Map<String, String>,
    ): List<Map<String, Any?>> {
        val offset = (page - 1) * 24
        val directUrl = if (mode == "latest") {
            "https://doujin.desu.xxx/api/manga?limit=24&offset=$offset&sort=latest_chapter"
        } else if (mode == "search" && query.isNotBlank()) {
            "https://doujin.desu.xxx/api/manga?limit=24&offset=$offset&search=" + java.net.URLEncoder.encode(query, "UTF-8")
        } else {
            "https://doujin.desu.xxx/api/manga?limit=24&offset=$offset&sort=rating"
        }
        val client = applyVpnDns(OkHttpClient.Builder().build())
        val req = Request.Builder()
            .url(directUrl)
            .header("User-Agent", "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36")
            .header("Referer", "https://doujin.desu.xxx/")
            .build()
        return client.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) throw IllegalStateException("HTTP ${resp.code}")
            parseDoujindesuMangas(resp.body.string(), sessionHeaders)
        }
    }

    private fun fetchDoujindesuDetailsDirect(
        mangaUrl: String,
        sessionHeaders: Map<String, String>,
    ): Map<String, Any?> {
        var slug = mangaUrl.trim()
        if (slug.startsWith("http://") || slug.startsWith("https://")) {
            slug = runCatching { java.net.URI.create(slug).path }.getOrDefault(slug)
        }
        slug = slug.removePrefix("/manga/").removePrefix("/api/manga/").removeSuffix("/")
        val client = applyVpnDns(OkHttpClient.Builder().build())
        val req = Request.Builder()
            .url("https://doujin.desu.xxx/api/manga/$slug")
            .header("User-Agent", "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36")
            .header("Referer", "https://doujin.desu.xxx/")
            .build()
        val body = client.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) throw IllegalStateException("HTTP ${resp.code}")
            resp.body.string()
        }
        var cleanJson = body.trim()
        if (cleanJson.contains("_enc_resp_")) {
            val encHex = JSONObject(cleanJson).optString("_enc_resp_")
            if (encHex.isNotBlank()) {
                cleanJson = decryptDoujindesu(encHex) ?: cleanJson
            }
        }
        val item = JSONObject(cleanJson)
        val status = when (item.optString("status").lowercase()) {
            "ongoing", "publishing" -> SManga.ONGOING
            "completed" -> SManga.COMPLETED
            else -> SManga.UNKNOWN
        }
        val genres = mutableListOf<String>()
        val rawGenres = item.optJSONArray("manga_genres")
        if (rawGenres != null) {
            for (i in 0 until rawGenres.length()) {
                val g = rawGenres.optJSONObject(i)?.optJSONObject("genre")?.optString("name")
                if (!g.isNullOrBlank()) genres.add(g)
            }
        }
        return mapOf(
            "title" to item.optString("title"),
            "url" to "/manga/$slug/",
            "thumbnailUrl" to item.optString("cover_url").ifBlank { null },
            "headers" to sessionHeaders,
            "author" to item.optString("author").ifBlank { null },
            "artist" to item.optString("artist").ifBlank { null },
            "description" to item.optString("description").ifBlank { null },
            "genre" to genres.joinToString(", ").ifBlank { null },
            "status" to status,
        )
    }

    private fun fetchDoujindesuChaptersDirect(
        mangaUrl: String,
    ): List<Map<String, Any?>> {
        var slug = mangaUrl.trim()
        if (slug.startsWith("http://") || slug.startsWith("https://")) {
            slug = runCatching { java.net.URI.create(slug).path }.getOrDefault(slug)
        }
        slug = slug.removePrefix("/manga/").removePrefix("/api/manga/").removeSuffix("/")
        val client = applyVpnDns(OkHttpClient.Builder().build())
        val req = Request.Builder()
            .url("https://doujin.desu.xxx/api/manga/$slug")
            .header("User-Agent", "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36")
            .header("Referer", "https://doujin.desu.xxx/")
            .build()
        val body = client.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) throw IllegalStateException("HTTP ${resp.code}")
            resp.body.string()
        }
        var cleanJson = body.trim()
        if (cleanJson.contains("_enc_resp_")) {
            val encHex = JSONObject(cleanJson).optString("_enc_resp_")
            if (encHex.isNotBlank()) {
                cleanJson = decryptDoujindesu(encHex) ?: cleanJson
            }
        }
        val item = JSONObject(cleanJson)
        val chapters = item.optJSONArray("chapters") ?: return emptyList()
        return buildList {
            for (i in 0 until chapters.length()) {
                val ch = chapters.optJSONObject(i) ?: continue
                val chId = ch.optString("id")
                val title = ch.optString("title").ifBlank { "Chapter ${ch.optString("chapter_number")}" }
                val chNum = ch.optDouble("chapter_number", -1.0).toFloat()
                val dateUpload = runCatching {
                    val str = ch.optString("created_at")
                    if (str.isNotBlank()) {
                        java.time.Instant.parse(str).toEpochMilli()
                    } else 0L
                }.getOrDefault(0L)
                add(
                    mapOf(
                        "url" to "/chapter/$chId",
                        "name" to title,
                        "dateUpload" to dateUpload,
                        "chapterNumber" to chNum,
                        "scanlator" to null,
                    )
                )
            }
        }
    }

    private fun fetchDoujindesuPagesDirect(
        chapterUrl: String,
        sessionHeaders: Map<String, String>,
    ): List<Map<String, Any?>> {
        var chId = chapterUrl.trim()
        if (chId.startsWith("http://") || chId.startsWith("https://")) {
            chId = runCatching { java.net.URI.create(chId).path }.getOrDefault(chId)
        }
        chId = chId.removePrefix("/chapter/").removePrefix("/api/chapters/").removeSuffix("/")
        val client = applyVpnDns(OkHttpClient.Builder().build())
        val req = Request.Builder()
            .url("https://doujin.desu.xxx/api/chapters/$chId")
            .header("User-Agent", "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36")
            .header("Referer", "https://doujin.desu.xxx/")
            .build()
        val body = client.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) throw IllegalStateException("HTTP ${resp.code}")
            resp.body.string()
        }
        var cleanJson = body.trim()
        if (cleanJson.contains("_enc_resp_")) {
            val encHex = JSONObject(cleanJson).optString("_enc_resp_")
            if (encHex.isNotBlank()) {
                cleanJson = decryptDoujindesu(encHex) ?: cleanJson
            }
        }
        val item = JSONObject(cleanJson)
        val contentUrls = item.optJSONArray("content_urls") ?: return emptyList()
        val imageHeaders = buildMap {
            put("Referer", "https://doujin.desu.xxx/")
            put("User-Agent", "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36")
            putAll(sessionHeaders)
        }
        return buildList {
            for (i in 0 until contentUrls.length()) {
                val url = contentUrls.optString(i)
                if (url.isNotBlank()) {
                    add(
                        mapOf(
                            "index" to i,
                            "url" to url,
                            "imageUrl" to url,
                            "headers" to imageHeaders,
                        )
                    )
                }
            }
        }
    }

    private fun fetchImhentaiCatalogDirect(
        mode: String,
        query: String,
        page: Int,
        sessionHeaders: Map<String, String>,
    ): List<Map<String, Any?>> {
        val url = when {
            query.isNotBlank() -> "https://imhentai.xxx/search/?key=${java.net.URLEncoder.encode(query.trim(), "UTF-8")}&page=$page"
            mode == "latest" -> "https://imhentai.xxx/?page=$page"
            else -> "https://imhentai.xxx/popular/?page=$page"
        }
        val client = applyVpnDns(OkHttpClient.Builder().build())
        val reqBuilder = Request.Builder()
            .url(url)
            .header("User-Agent", sessionHeaders["User-Agent"] ?: "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36")
            .header("Referer", "https://imhentai.xxx/")
        sessionHeaders["Cookie"]?.let { reqBuilder.header("Cookie", it) }
        val body = client.newCall(reqBuilder.build()).execute().use { resp ->
            if (!resp.isSuccessful) throw IllegalStateException("HTTP ${resp.code}")
            resp.body.string()
        }
        val doc = org.jsoup.Jsoup.parse(body, "https://imhentai.xxx/")
        val thumbs = doc.select("div.thumb")
        return buildList {
            for (thumb in thumbs) {
                val captionEl = thumb.selectFirst(".caption")
                val title = captionEl?.text()?.trim() ?: ""
                if (title.isBlank()) continue
                val linkEl = thumb.selectFirst(".inner_thumb a")
                val href = linkEl?.attr("href")?.trim() ?: ""
                if (href.isBlank()) continue
                val imgEl = thumb.selectFirst(".inner_thumb img")
                val thumbUrl = imgEl?.attr("data-src")?.ifBlank { null }
                    ?: imgEl?.attr("src")?.ifBlank { null }
                val fullUrl = if (href.startsWith("http://") || href.startsWith("https://")) href else "https://imhentai.xxx$href"
                add(
                    mapOf(
                        "title" to title,
                        "url" to fullUrl,
                        "thumbnailUrl" to thumbUrl,
                        "headers" to mapOf("Referer" to "https://imhentai.xxx/"),
                        "status" to SManga.COMPLETED,
                    )
                )
            }
        }
    }

    private fun fetchImhentaiDetailsDirect(
        mangaUrl: String,
        sessionHeaders: Map<String, String>,
    ): Map<String, Any?> {
        val fullUrl = if (mangaUrl.startsWith("http://") || mangaUrl.startsWith("https://")) {
            mangaUrl
        } else {
            "https://imhentai.xxx${if (mangaUrl.startsWith("/")) "" else "/"}$mangaUrl"
        }
        val client = applyVpnDns(OkHttpClient.Builder().build())
        val reqBuilder = Request.Builder()
            .url(fullUrl)
            .header("User-Agent", sessionHeaders["User-Agent"] ?: "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36")
            .header("Referer", "https://imhentai.xxx/")
        sessionHeaders["Cookie"]?.let { reqBuilder.header("Cookie", it) }
        val body = client.newCall(reqBuilder.build()).execute().use { resp ->
            if (!resp.isSuccessful) throw IllegalStateException("HTTP ${resp.code}")
            resp.body.string()
        }
        val doc = org.jsoup.Jsoup.parse(body, "https://imhentai.xxx/")
        val title = doc.selectFirst("h1")?.text()?.trim() ?: "Untitled"
        val coverEl = doc.selectFirst(".left_cover img") ?: doc.selectFirst(".cover img")
        val coverUrl = coverEl?.attr("data-src")?.ifBlank { null } ?: coverEl?.attr("src")?.ifBlank { null }
        val tags = doc.select("a.tag").map { it.text().trim() }.filter { it.isNotBlank() }.distinct()
        val authorEl = doc.select("li").firstOrNull { it.selectFirst(".tags_text")?.text()?.contains("Artists:") == true }
            ?.select("a.tag")?.firstOrNull()
        val author = authorEl?.text()?.trim()
        val totalPages = doc.selectFirst("input#load_pages")?.attr("value")?.trim()
        val subtitle = doc.selectFirst("h1 + h2, .subtitle")?.text()?.trim()
        val descParts = mutableListOf<String>()
        if (!totalPages.isNullOrBlank()) descParts.add("Pages: $totalPages")
        if (!subtitle.isNullOrBlank()) descParts.add("Subtitle: $subtitle")

        return mapOf(
            "title" to title,
            "url" to fullUrl,
            "thumbnailUrl" to coverUrl,
            "headers" to mapOf("Referer" to "https://imhentai.xxx/"),
            "author" to author,
            "artist" to author,
            "description" to descParts.joinToString("\n").ifBlank { null },
            "genre" to tags.joinToString(", ").ifBlank { null },
            "status" to SManga.COMPLETED,
        )
    }

    private fun fetchImhentaiChaptersDirect(
        mangaUrl: String,
        sessionHeaders: Map<String, String>,
    ): List<Map<String, Any?>> {
        val fullUrl = if (mangaUrl.startsWith("http://") || mangaUrl.startsWith("https://")) {
            mangaUrl
        } else {
            "https://imhentai.xxx${if (mangaUrl.startsWith("/")) "" else "/"}$mangaUrl"
        }
        return listOf(
            mapOf(
                "url" to fullUrl,
                "name" to "Full Gallery",
                "dateUpload" to System.currentTimeMillis(),
                "chapterNumber" to 1.0f,
                "scanlator" to null,
            )
        )
    }

    private fun fetchImhentaiPagesDirect(
        chapterUrl: String,
        sessionHeaders: Map<String, String>,
    ): List<Map<String, Any?>> {
        val fullUrl = if (chapterUrl.startsWith("http://") || chapterUrl.startsWith("https://")) {
            chapterUrl
        } else {
            "https://imhentai.xxx${if (chapterUrl.startsWith("/")) "" else "/"}$chapterUrl"
        }
        val client = applyVpnDns(OkHttpClient.Builder().build())
        val reqBuilder = Request.Builder()
            .url(fullUrl)
            .header("User-Agent", sessionHeaders["User-Agent"] ?: "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36")
            .header("Referer", "https://imhentai.xxx/")
        sessionHeaders["Cookie"]?.let { reqBuilder.header("Cookie", it) }
        val body = client.newCall(reqBuilder.build()).execute().use { resp ->
            if (!resp.isSuccessful) throw IllegalStateException("HTTP ${resp.code}")
            resp.body.string()
        }
        val doc = org.jsoup.Jsoup.parse(body, "https://imhentai.xxx/")
        val loadServer = doc.selectFirst("input#load_server")?.attr("value")?.trim() ?: ""
        val loadDir = doc.selectFirst("input#load_dir")?.attr("value")?.trim() ?: ""
        val loadId = doc.selectFirst("input#load_id")?.attr("value")?.trim() ?: ""
        val totalPages = doc.selectFirst("input#load_pages")?.attr("value")?.trim()?.toIntOrNull() ?: 0
        val serverHost = if (loadServer.isNotBlank()) "m$loadServer.imhentai.xxx" else "m1.imhentai.xxx"

        val imageHeaders = buildMap {
            put("Referer", "https://imhentai.xxx/")
            put("User-Agent", sessionHeaders["User-Agent"] ?: "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36")
            putAll(sessionHeaders)
        }

        val scriptContent = doc.select("script").map { it.data() }.firstOrNull { it.contains("parseJSON(") } ?: ""
        val pages = mutableListOf<Map<String, Any?>>()

        if (scriptContent.isNotBlank() && loadDir.isNotBlank() && loadId.isNotBlank()) {
            val match = Regex("""parseJSON\('([^']+)'\)""").find(scriptContent)
            val rawJson = match?.groupValues?.getOrNull(1)
            if (!rawJson.isNullOrBlank()) {
                runCatching {
                    val jsonObj = JSONObject(rawJson)
                    val keys = jsonObj.keys().asSequence().toList().sortedBy { it.toIntOrNull() ?: 0 }
                    for (k in keys) {
                        val rawVal = jsonObj.optString(k, "")
                        val extCode = rawVal.split(",").firstOrNull()?.replace("\"", "")?.trim() ?: ""
                        val ext = when (extCode) {
                            "p" -> "png"
                            "b" -> "bmp"
                            "g" -> "gif"
                            "w" -> "webp"
                            else -> "jpg"
                        }
                        val pageNum = k.toIntOrNull() ?: 1
                        val pageIdx = pageNum - 1
                        val imgUrl = "https://$serverHost/$loadDir/$loadId/$k.$ext"
                        pages.add(
                            mapOf(
                                "index" to pageIdx,
                                "url" to "https://imhentai.xxx/view/$loadId/$k/",
                                "imageUrl" to imgUrl,
                                "headers" to imageHeaders,
                            )
                        )
                    }
                }
            }
        }

        if (pages.isNotEmpty()) return pages

        val thumbImgs = doc.select(".gthumb img, .gallery_thumb img")
        if (thumbImgs.isNotEmpty()) {
            for (i in thumbImgs.indices) {
                val tUrl = thumbImgs[i].attr("data-src").ifBlank { null } ?: thumbImgs[i].attr("src").ifBlank { null } ?: ""
                if (tUrl.isBlank()) continue
                val fullImgUrl = tUrl.replace(Regex("""t\.([a-zA-Z]+)$"""), ".$1")
                pages.add(
                    mapOf(
                        "index" to i,
                        "url" to "https://imhentai.xxx/view/$loadId/${i + 1}/",
                        "imageUrl" to fullImgUrl,
                        "headers" to imageHeaders,
                    )
                )
            }
            return pages
        }

        if (totalPages > 0 && loadDir.isNotBlank() && loadId.isNotBlank()) {
            for (i in 1..totalPages) {
                pages.add(
                    mapOf(
                        "index" to (i - 1),
                        "url" to "https://imhentai.xxx/view/$loadId/$i/",
                        "imageUrl" to "https://$serverHost/$loadDir/$loadId/$i.jpg",
                        "headers" to imageHeaders,
                    )
                )
            }
        }

        return pages
    }

    private fun org.jsoup.nodes.Document.absUrl(raw: String, base: String): String =
        runCatching {
            java.net.URI.create(base).resolve(raw).toString()
        }.getOrDefault(raw)

    private fun String.looksLikeReaderImage(): Boolean {
        val value = lowercase()
        if (
            value.startsWith("data:") ||
            value.contains("placeholder") ||
            value.contains("loading.") ||
            value.contains("blank.") ||
            value.contains("/logo") ||
            value.contains("/icon") ||
            value.contains("/avatar") ||
            value.contains("/ads")
        ) {
            return false
        }
        return value.contains(".jpg") ||
            value.contains(".jpeg") ||
            value.contains(".png") ||
            value.contains(".webp") ||
            value.contains(".avif")
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
        if (finalImageUrl.isNullOrBlank()) {
            finalImageUrl = runCatching {
                invokeSuspend(sourceInstance, "getImageUrl", this) as? String
            }.getOrNull()
        }
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
        fun absoluteUrlForSource(rawUrl: String): String {
            val value = rawUrl.trim()
            if (value.startsWith("http://") || value.startsWith("https://")) return value
            val base = instance.callOrNull("getBaseUrl") as? String ?: return value
            return runCatching { java.net.URI.create(base).resolve(value).toString() }
                .getOrDefault(value)
        }

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
        @Volatile
        var instance: ExtensionRuntimeBridge? = null
            private set

        fun onVpnStopped() {
            instance?.let { bridge ->
                bridge.vpnEnabled = false
                try {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        try {
                            bridge.channel.invokeMethod(
                                "onVpnStatusChanged",
                                mapOf("enabled" to false, "isRunning" to false)
                            )
                        } catch (_: Throwable) {}
                    }
                } catch (_: Throwable) {}
            }
        }
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
        private const val API_VERSION = 1
        // Cloudflare biasanya redirect sekali setelah cookie clearance aktif.
        // Beri waktu JavaScript normal selesai, tanpa menyentuh CAPTCHA.
        private const val WEBVIEW_RENDER_SETTLE_MS = 2_500L
        private const val WEBVIEW_RENDER_TIMEOUT_MS = 12_000L
        private val IMAGE_URL_REGEX =
            Regex(
                """(?:https?:)?(?:\\?/){2}[^"'\\\s<>]+\.(?:jpg|jpeg|png|webp|avif)(?:\?[^"'\s<>]*)?|(?:\\?/)?(?:wp-content|uploads|images|image|img|storage|reader|pages|manga|doujin|doujindesu)(?:\\?/|[^"'\\\s<>])+\.(?:jpg|jpeg|png|webp|avif)(?:\?[^"'\s<>]*)?""",
                RegexOption.IGNORE_CASE,
            )
        private val WEBVIEW_RENDER_SCRIPT = """
            (function() {
              var element = document.documentElement || document.body;
              return element ? element.outerHTML : '';
            })()
        """.trimIndent()
        private val constEmptyList = emptyList<Any?>()
    }
}

/**
 * DNS-over-HTTPS (DoH) resolver untuk membypass blokir ISP/Internet Positif
 * di jaringan Indonesia secara otomatis tanpa memerlukan akses root.
 */
class DohDns(private val provider: String = "cloudflare") : Dns {
    private val bootstrapDns = Dns { hostname ->
        when (hostname.lowercase()) {
            "cloudflare-dns.com", "one.one.one.one" -> listOf(
                InetAddress.getByAddress(hostname, byteArrayOf(1, 1, 1, 1)),
                InetAddress.getByAddress(hostname, byteArrayOf(1, 0, 0, 1)),
            )
            "dns.google" -> listOf(
                InetAddress.getByAddress(hostname, byteArrayOf(8, 8, 8, 8)),
                InetAddress.getByAddress(hostname, byteArrayOf(8, 8, 4, 4)),
            )
            "dns.adguard-dns.com" -> listOf(
                InetAddress.getByAddress(hostname, byteArrayOf(94.toByte(), 140.toByte(), 14, 14)),
                InetAddress.getByAddress(hostname, byteArrayOf(94.toByte(), 140.toByte(), 15, 15)),
            )
            "doh.dns.sb" -> listOf(
                InetAddress.getByAddress(hostname, byteArrayOf(185.toByte(), 222.toByte(), 222.toByte(), 222.toByte())),
                InetAddress.getByAddress(hostname, byteArrayOf(45, 11, 45, 11)),
            )
            else -> listOf(InetAddress.getByAddress(hostname, byteArrayOf(1, 1, 1, 1)))
        }
    }

    private val client by lazy {
        OkHttpClient.Builder()
            .dns(bootstrapDns)
            .callTimeout(java.time.Duration.ofSeconds(4))
            .connectTimeout(java.time.Duration.ofSeconds(3))
            .readTimeout(java.time.Duration.ofSeconds(3))
            .build()
    }

    private fun isBlockedIp(ip: String): Boolean {
        return ip.startsWith("36.86.") ||
                ip.startsWith("180.250.") ||
                ip.startsWith("118.98.") ||
                ip.startsWith("103.236.") ||
                ip == "127.0.0.1" ||
                ip == "0.0.0.0"
    }

    override fun lookup(hostname: String): List<InetAddress> {
        if (hostname.matches(Regex("^[0-9.]+$")) || hostname.contains(":")) {
            return InetAddress.getAllByName(hostname).toList()
        }
        try {
            val url = when (provider) {
                "hongkong" -> "https://doh.dns.sb/dns-query?name=$hostname&type=A"
                "google" -> "https://dns.google/resolve?name=$hostname&type=A"
                "adguard" -> "https://dns.adguard-dns.com/dns-query?name=$hostname&type=A"
                else -> "https://cloudflare-dns.com/dns-query?name=$hostname&type=A"
            }
            val request = Request.Builder()
                .url(url)
                .header("Accept", "application/dns-json")
                .get()
                .build()

            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val body = response.body.string()
                    val json = org.json.JSONObject(body)
                    val answers = json.optJSONArray("Answer")
                    if (answers != null && answers.length() > 0) {
                        val addresses = mutableListOf<InetAddress>()
                        for (i in 0 until answers.length()) {
                            val ans = answers.getJSONObject(i)
                            val type = ans.optInt("type", 1)
                            if (type == 1) {
                                val ip = ans.optString("data")
                                if (!ip.isNullOrBlank() && !isBlockedIp(ip)) {
                                    addresses.addAll(InetAddress.getAllByName(ip))
                                }
                            }
                        }
                        if (addresses.isNotEmpty()) {
                            return addresses
                        }
                    }
                }
            }
        } catch (e: Throwable) {
            Log.w("KizenDoH", "DoH lookup failed for $hostname: ${e.message}")
        }

        // Jangan fallback ke DNS sistem yang diinjeksi Nawala jika domain komik terkenal
        val hostLower = hostname.lowercase()
        val safeFallback = when {
            hostLower == "doujindesu.tv" || hostLower == "doujin.desu.xxx" || hostLower == "doujindesu.bid" -> listOf(
                InetAddress.getByAddress(hostname, byteArrayOf(104, 26, 1, 249.toByte())),
                InetAddress.getByAddress(hostname, byteArrayOf(172.toByte(), 67, 72, 203.toByte())),
                InetAddress.getByAddress(hostname, byteArrayOf(104, 26, 0, 249.toByte())),
            )
            hostLower == "imhentai.xxx" || hostLower.endsWith(".imhentai.xxx") || hostLower == "imhentai.com" || hostLower == "imhentai.to" -> listOf(
                InetAddress.getByAddress(hostname, byteArrayOf(104, 26, 11, 15)),
                InetAddress.getByAddress(hostname, byteArrayOf(172.toByte(), 67, 73, 234.toByte())),
                InetAddress.getByAddress(hostname, byteArrayOf(104, 26, 10, 15)),
            )
            hostLower == "e-hentai.org" -> listOf(
                InetAddress.getByAddress(hostname, byteArrayOf(104, 20, 134.toByte(), 21)),
                InetAddress.getByAddress(hostname, byteArrayOf(172.toByte(), 67, 2.toByte(), 187.toByte())),
            )
            hostLower == "toongod.org" || hostLower == "www.toongod.org" || hostLower == "toongod.cc" -> listOf(
                InetAddress.getByAddress(hostname, byteArrayOf(104, 21, 32, 187.toByte())),
                InetAddress.getByAddress(hostname, byteArrayOf(172.toByte(), 67, 189.toByte(), 155.toByte())),
            )
            else -> null
        }
        if (safeFallback != null) return safeFallback

        return Dns.SYSTEM.lookup(hostname).filterNot { isBlockedIp(it.hostAddress ?: "") }
    }
}
