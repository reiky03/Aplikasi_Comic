package com.reikypratama.aplikasi_komik.vpn

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import com.wireguard.crypto.Key
import com.wireguard.crypto.KeyPair
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.time.Instant
import java.util.concurrent.TimeUnit

/**
 * KizenWireguardManager: Pengelola WireGuard Full-Tunnel VPN Kizen.
 *
 * Menggunakan engine WireGuard resmi (GoBackend & libwg-go.so) dan jaringan Anycast Cloudflare WARP.
 * Me-routing SELURUH TRAFIK IP (0.0.0.0/0, ::/0) di level Android OS sehingga:
 * 1. Seluruh web komik (Doujindesu, ImHentai, E-Hentai, Shinigami, Komiku, dll) tembus dari blokir ISP.
 * 2. Aplikasi lain di HP (seperti Chrome, Mihon, browser) juga ikut terlindungi dan bisa membuka web yang diblokir.
 * 3. 100% terintegrasi di dalam Kizen tanpa perlu install VPN luar dari Play Store.
 */
object KizenWireguardManager {
    private const val TAG = "KizenWireguard"
    private const val PREFS_NAME = "kizen_wireguard_prefs"
    private const val PREF_PRIVATE_KEY = "wg_private_key"
    private const val PREF_PUBLIC_KEY = "wg_public_key"
    private const val PREF_CLIENT_IPV4 = "wg_client_ipv4"
    private const val PREF_PEER_PUBLIC_KEY = "wg_peer_public_key"
    private const val PREF_ENDPOINT = "wg_endpoint"

    private const val DEFAULT_PEER_KEY = "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo="
    private const val DEFAULT_CLIENT_IP = "172.16.0.2"

    @Volatile
    var isRunning = false
        private set

    @Volatile
    var currentProvider = "cloudflare"

    private var backend: GoBackend? = null
    private val kizenTunnel = object : Tunnel {
        override fun getName(): String = "kizen_vpn"
        override fun onStateChange(newState: Tunnel.State) {
            Log.i(TAG, "WireGuard Tunnel state change: $newState")
            isRunning = (newState == Tunnel.State.UP)
        }
    }

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .build()

    fun getBackend(context: Context): GoBackend {
        return backend ?: synchronized(this) {
            backend ?: GoBackend(context.applicationContext).also { backend = it }
        }
    }

    /**
     * Memulai koneksi WireGuard tunnel penuh.
     */
    fun startTunnel(context: Context, provider: String, onComplete: (Boolean) -> Unit) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                currentProvider = provider
                val wgBackend = getBackend(context)

                // Pastikan registrasi WARP tersedia
                val creds = ensureWarpRegistration(context)
                val endpoint = resolveEndpoint(provider, creds.endpoint)
                val config = buildConfig(creds, endpoint, provider)

                Log.i(TAG, "Menghubungkan WireGuard tunnel ke endpoint: $endpoint (Provider: $provider)")
                wgBackend.setState(kizenTunnel, Tunnel.State.UP, config)
                isRunning = true

                withContext(Dispatchers.Main) {
                    onComplete(true)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Gagal mengaktifkan WireGuard tunnel", e)
                isRunning = false
                withContext(Dispatchers.Main) {
                    onComplete(false)
                }
            }
        }
    }

    /**
     * Memutuskan koneksi WireGuard tunnel.
     */
    fun stopTunnel(context: Context, onComplete: (Boolean) -> Unit) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val wgBackend = getBackend(context)
                wgBackend.setState(kizenTunnel, Tunnel.State.DOWN, null)
                isRunning = false
                Log.i(TAG, "WireGuard tunnel berhasil dinonaktifkan")
                withContext(Dispatchers.Main) {
                    onComplete(true)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Gagal mematikan WireGuard tunnel", e)
                withContext(Dispatchers.Main) {
                    onComplete(false)
                }
            }
        }
    }

    private data class WarpCredentials(
        val privateKey: String,
        val publicKey: String,
        val clientIpv4: String,
        val peerPublicKey: String,
        val endpoint: String
    )

    private fun ensureWarpRegistration(context: Context): WarpCredentials {
        val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val savedPrivate = prefs.getString(PREF_PRIVATE_KEY, null)
        val savedPublic = prefs.getString(PREF_PUBLIC_KEY, null)
        val savedClientIp = prefs.getString(PREF_CLIENT_IPV4, null)
        val savedPeerKey = prefs.getString(PREF_PEER_PUBLIC_KEY, null)
        val savedEndpoint = prefs.getString(PREF_ENDPOINT, null)

        if (!savedPrivate.isNullOrBlank() && !savedPublic.isNullOrBlank() && !savedClientIp.isNullOrBlank()) {
            return WarpCredentials(
                privateKey = savedPrivate,
                publicKey = savedPublic,
                clientIpv4 = savedClientIp,
                peerPublicKey = savedPeerKey ?: DEFAULT_PEER_KEY,
                endpoint = savedEndpoint ?: "162.159.192.1:2408"
            )
        }

        // Generate KeyPair Curve25519 baru
        val keyPair = KeyPair()
        val privateKey = keyPair.privateKey.toBase64()
        val publicKey = keyPair.publicKey.toBase64()

        var clientIpv4 = DEFAULT_CLIENT_IP
        var peerPublicKey = DEFAULT_PEER_KEY
        var endpoint = "162.159.192.1:2408"

        try {
            val jsonMediaType = "application/json; charset=utf-8".toMediaType()
            val requestBody = JSONObject().apply {
                put("install_id", "")
                put("tos", Instant.now().toString())
                put("key", publicKey)
                put("fcm_token", "")
                put("type", "android")
                put("model", "Kizen Mobile")
            }.toString().toRequestBody(jsonMediaType)

            val request = Request.Builder()
                .url("https://api.cloudflareclient.com/v0a884/reg")
                .addHeader("User-Agent", "okhttp/3.12.1")
                .addHeader("CF-ClientVersion", "a-6.3-2158")
                .post(requestBody)
                .build()

            httpClient.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val respString = response.body.string()
                    val data = JSONObject(respString)
                    val configObj = data.optJSONObject("config")
                    if (configObj != null) {
                        val interfaceObj = configObj.optJSONObject("interface")
                        val addressesObj = interfaceObj?.optJSONObject("addresses")
                        val ipv4 = addressesObj?.optString("v4")
                        if (!ipv4.isNullOrBlank()) {
                            clientIpv4 = ipv4
                        }

                        val peersArr = configObj.optJSONArray("peers")
                        if (peersArr != null && peersArr.length() > 0) {
                            val peer0 = peersArr.getJSONObject(0)
                            val pubKey = peer0.optString("public_key")
                            if (!pubKey.isNullOrBlank()) {
                                peerPublicKey = pubKey
                            }
                            val endpointObj = peer0.optJSONObject("endpoint")
                            val v4Endpoint = endpointObj?.optString("v4")
                            if (!v4Endpoint.isNullOrBlank()) {
                                endpoint = v4Endpoint
                            }
                        }
                    }
                    Log.i(TAG, "Registrasi Cloudflare WARP sukses! Client IP: $clientIpv4")
                } else {
                    Log.w(TAG, "Registrasi WARP gagal dengan status code ${response.code}, menggunakan parameter default")
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error saat registrasi Cloudflare WARP, fallback ke default", e)
        }

        // Simpan ke SharedPreferences
        prefs.edit()
            .putString(PREF_PRIVATE_KEY, privateKey)
            .putString(PREF_PUBLIC_KEY, publicKey)
            .putString(PREF_CLIENT_IPV4, clientIpv4)
            .putString(PREF_PEER_PUBLIC_KEY, peerPublicKey)
            .putString(PREF_ENDPOINT, endpoint)
            .apply()

        return WarpCredentials(
            privateKey = privateKey,
            publicKey = publicKey,
            clientIpv4 = clientIpv4,
            peerPublicKey = peerPublicKey,
            endpoint = endpoint
        )
    }

    private fun resolveEndpoint(provider: String, fallbackEndpoint: String): String {
        return when (provider.lowercase()) {
            "hongkong" -> "162.159.193.1:2408"   // Cloudflare Hong Kong Anycast
            "google" -> "162.159.195.1:2408"     // Cloudflare Anycast Global
            "adguard" -> "162.159.192.5:2408"    // Cloudflare Anycast AdGuard Pair
            else -> "162.159.192.1:2408"         // Cloudflare Singapore Anycast
        }
    }

    private fun buildConfig(creds: WarpCredentials, endpoint: String, provider: String): Config {
        val dnsServers = when (provider.lowercase()) {
            "google" -> "8.8.8.8, 8.8.4.4"
            "adguard" -> "94.140.14.14, 94.140.15.15"
            "hongkong" -> "1.1.1.1, 185.222.222.222"
            else -> "1.1.1.1, 1.0.0.1"
        }

        // wg-quick format configuration
        val confText = """
            [Interface]
            PrivateKey = ${creds.privateKey}
            Address = ${creds.clientIpv4}/32
            DNS = $dnsServers

            [Peer]
            PublicKey = ${creds.peerPublicKey}
            Endpoint = $endpoint
            AllowedIPs = 0.0.0.0/0, ::/0
            PersistentKeepalive = 25
        """.trimIndent()

        return Config.parse(ByteArrayInputStream(confText.toByteArray(Charsets.UTF_8)))
    }
}
