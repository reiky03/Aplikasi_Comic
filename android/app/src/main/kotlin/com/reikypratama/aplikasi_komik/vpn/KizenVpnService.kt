package com.reikypratama.aplikasi_komik.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import com.reikypratama.aplikasi_komik.MainActivity
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.Socket
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.net.SocketFactory

/**
 * KizenVpnService: Native Android VpnService implementation.
 *
 * Mengarahkan trafik DNS Android OS ke antarmuka TUN virtual,
 * lalu membungkus query DNS wire-format ke dalam DoH (DNS-over-HTTPS)
 * terenkripsi ke Cloudflare (1.1.1.1), Google, AdGuard, atau Hong Kong (DNS.SB).
 *
 * Ini memicu dialog izin resmi Android OS ("Kizen ingin menyiapkan koneksi VPN...")
 * dan menampilkan ikon kunci [🔑] di status bar HP.
 */
class KizenVpnService : VpnService(), Runnable {

    companion object {
        const val TAG = "KizenVpnService"
        const val ACTION_START = "com.reikypratama.aplikasi_komik.vpn.START"
        const val ACTION_STOP = "com.reikypratama.aplikasi_komik.vpn.STOP"
        const val CHANNEL_ID = "kizen_vpn_channel"
        const val NOTIFICATION_ID = 9021

        const val TUN_IP = "10.222.0.1"
        const val DNS_IP = "10.222.0.2"

        @Volatile
        var isRunning = false
            private set

        @Volatile
        var currentProvider = "cloudflare"
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnThread: Thread? = null
    private var executor: ExecutorService? = null
    private lateinit var httpClient: OkHttpClient

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        // OkHttpClient yang mengecualikan socket-nya dari interface VPN
        val protectedSocketFactory = object : SocketFactory() {
            private val defaultFactory = SocketFactory.getDefault()
            override fun createSocket(): Socket {
                val socket = defaultFactory.createSocket()
                protect(socket)
                return socket
            }
            override fun createSocket(host: String?, port: Int) = defaultFactory.createSocket(host, port).also { protect(it) }
            override fun createSocket(host: String?, port: Int, localHost: java.net.InetAddress?, localPort: Int) =
                defaultFactory.createSocket(host, port, localHost, localPort).also { protect(it) }
            override fun createSocket(host: java.net.InetAddress?, port: Int) = defaultFactory.createSocket(host, port).also { protect(it) }
            override fun createSocket(address: java.net.InetAddress?, port: Int, localAddress: java.net.InetAddress?, localPort: Int) =
                defaultFactory.createSocket(address, port, localAddress, localPort).also { protect(it) }
        }

        httpClient = OkHttpClient.Builder()
            .socketFactory(protectedSocketFactory)
            .connectTimeout(5, TimeUnit.SECONDS)
            .readTimeout(5, TimeUnit.SECONDS)
            .followRedirects(true)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START
        val provider = intent?.getStringExtra("provider") ?: currentProvider
        currentProvider = provider

        if (action == ACTION_STOP) {
            stopVpn()
            return START_NOT_STICKY
        }

        startForeground(NOTIFICATION_ID, buildNotification(provider))
        startVpnTunnel()

        return START_STICKY
    }

    private fun startVpnTunnel() {
        if (isRunning) return

        try {
            val builder = Builder()
                .setSession("Kizen Anti-Blokir")
                .addAddress(TUN_IP, 30)
                .addDnsServer(DNS_IP)
                .addRoute("10.222.0.0", 30) // Hanya rute IP DNS virtual ke TUN, trafik normal tetap native
                .setMtu(1500)
                .setBlocking(true)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }

            vpnInterface = builder.establish()
            if (vpnInterface == null) {
                Log.e(TAG, "Gagal establish VpnService Builder (interface null)")
                stopSelf()
                return
            }

            isRunning = true
            executor = Executors.newFixedThreadPool(4)
            vpnThread = Thread(this, "KizenVpnTunnel").apply { start() }
            Log.i(TAG, "KizenVpnService berhasil aktif dengan provider: $currentProvider")
        } catch (e: Throwable) {
            Log.e(TAG, "Error saat establish VPN interface", e)
            stopSelf()
        }
    }

    override fun run() {
        val pfd = vpnInterface ?: return
        val inStream = FileInputStream(pfd.fileDescriptor)
        val outStream = FileOutputStream(pfd.fileDescriptor)
        val packet = ByteArray(32767)

        try {
            while (isRunning) {
                val length = inStream.read(packet)
                if (length <= 0) break

                // Validasi header IPv4 dasar (panjang min 28 = 20 IPv4 + 8 UDP)
                if (length < 28) continue
                if ((packet[0].toInt() and 0xF0) != 0x40) continue // Hanya IPv4
                val ipHeaderLen = (packet[0].toInt() and 0x0F) * 4
                val protocol = packet[9].toInt() and 0xFF
                if (protocol != 17) continue // UDP = 17

                val destPort = ((packet[ipHeaderLen + 2].toInt() and 0xFF) shl 8) or
                        (packet[ipHeaderLen + 3].toInt() and 0xFF)
                if (destPort != 53) continue // Hanya proses DNS

                val srcPort = ((packet[ipHeaderLen].toInt() and 0xFF) shl 8) or
                        (packet[ipHeaderLen + 1].toInt() and 0xFF)

                val udpLen = ((packet[ipHeaderLen + 4].toInt() and 0xFF) shl 8) or
                        (packet[ipHeaderLen + 5].toInt() and 0xFF)
                val dnsPayloadLen = udpLen - 8
                if (dnsPayloadLen <= 0 || ipHeaderLen + 8 + dnsPayloadLen > length) continue

                val dnsQuery = packet.copyOfRange(ipHeaderLen + 8, ipHeaderLen + 8 + dnsPayloadLen)
                val clientIp = packet.copyOfRange(12, 16)
                val destIp = packet.copyOfRange(16, 20)

                // Teruskan DNS wire query ke DoH secara asynchronous
                executor?.execute {
                    handleDnsQuery(dnsQuery, clientIp, destIp, srcPort, destPort, outStream)
                }
            }
        } catch (e: Throwable) {
            if (isRunning) {
                Log.w(TAG, "VPN read loop error: ${e.message}")
            }
        } finally {
            isRunning = false
        }
    }

    private fun handleDnsQuery(
        dnsQuery: ByteArray,
        clientIp: ByteArray,
        destIp: ByteArray,
        clientPort: Int,
        dnsPort: Int,
        outStream: FileOutputStream,
    ) {
        val dohUrl = when (currentProvider.lowercase()) {
            "google" -> "https://dns.google/dns-query"
            "adguard" -> "https://dns.adguard-dns.com/dns-query"
            "hongkong" -> "https://doh.dns.sb/dns-query"
            else -> "https://cloudflare-dns.com/dns-query"
        }

        try {
            val request = Request.Builder()
                .url(dohUrl)
                .header("Content-Type", "application/dns-message")
                .header("Accept", "application/dns-message")
                .post(dnsQuery.toRequestBody("application/dns-message".toMediaType()))
                .build()

            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return
                val dnsResponse = response.body.bytes()
                if (dnsResponse.isEmpty()) return

                // Bangun paket balasan IPv4 + UDP
                val totalLen = 20 + 8 + dnsResponse.size
                val replyPacket = ByteArray(totalLen)

                // IPv4 Header
                replyPacket[0] = 0x45.toByte() // IPv4, IHL 5 (20 bytes)
                replyPacket[1] = 0x00.toByte() // ToS
                replyPacket[2] = ((totalLen shr 8) and 0xFF).toByte()
                replyPacket[3] = (totalLen and 0xFF).toByte()
                replyPacket[4] = 0x12.toByte() // ID
                replyPacket[5] = 0x34.toByte()
                replyPacket[6] = 0x40.toByte() // Don't Fragment
                replyPacket[7] = 0x00.toByte()
                replyPacket[8] = 64.toByte()   // TTL
                replyPacket[9] = 17.toByte()   // Protocol UDP
                // Checksum nanti dihitung di bytes 10..11
                System.arraycopy(destIp, 0, replyPacket, 12, 4)   // Source = DNS IP
                System.arraycopy(clientIp, 0, replyPacket, 16, 4) // Dest = Client IP

                // Hitung IPv4 Header Checksum
                val ipChecksum = computeChecksum(replyPacket, 0, 20)
                replyPacket[10] = ((ipChecksum shr 8) and 0xFF).toByte()
                replyPacket[11] = (ipChecksum and 0xFF).toByte()

                // UDP Header
                replyPacket[20] = ((dnsPort shr 8) and 0xFF).toByte()
                replyPacket[21] = (dnsPort and 0xFF).toByte()
                replyPacket[22] = ((clientPort shr 8) and 0xFF).toByte()
                replyPacket[23] = (clientPort and 0xFF).toByte()
                val udpTotalLen = 8 + dnsResponse.size
                replyPacket[24] = ((udpTotalLen shr 8) and 0xFF).toByte()
                replyPacket[25] = (udpTotalLen and 0xFF).toByte()
                replyPacket[26] = 0x00.toByte() // UDP checksum opsional (0 di IPv4)
                replyPacket[27] = 0x00.toByte()

                // Payload DNS
                System.arraycopy(dnsResponse, 0, replyPacket, 28, dnsResponse.size)

                synchronized(outStream) {
                    outStream.write(replyPacket)
                    outStream.flush()
                }
            }
        } catch (_: Throwable) {
            // Abaikan query individual yang gagal/timeout agar thread pool tetap sehat
        }
    }

    private fun computeChecksum(data: ByteArray, offset: Int, length: Int): Int {
        var sum = 0
        var i = offset
        while (i < offset + length) {
            val high = data[i].toInt() and 0xFF
            val low = if (i + 1 < offset + length) data[i + 1].toInt() and 0xFF else 0
            sum += (high shl 8) or low
            i += 2
        }
        while ((sum shr 16) > 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }
        return sum.inv() and 0xFFFF
    }

    private fun stopVpn() {
        isRunning = false
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (_: Throwable) {}

        try {
            executor?.shutdownNow()
            executor = null
        } catch (_: Throwable) {}

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.i(TAG, "KizenVpnService berhasil dimatikan")
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Kizen Anti-Blokir VPN",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Status koneksi VPN terenkripsi DoH Kizen"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(provider: String): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val serverName = when (provider.lowercase()) {
            "hongkong" -> "Hong Kong (DNS.SB)"
            "google" -> "Google DNS"
            "adguard" -> "AdGuard Shield"
            else -> "Cloudflare (1.1.1.1)"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Kizen VPN Aktif")
            .setContentText("Bebas Blokir & Terenkripsi · $serverName")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
