package com.reikypratama.aplikasi_komik

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import androidx.core.content.ContextCompat
import com.reikypratama.aplikasi_komik.extensions.ExtensionRuntimeBridge
import com.reikypratama.aplikasi_komik.vpn.KizenVpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pendingVpnResult: MethodChannel.Result? = null
    private var pendingProvider: String = "cloudflare"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ExtensionRuntimeBridge(this).register(flutterEngine.dartExecutor.binaryMessenger)
    }

    /**
     * Meminta izin VpnService Android OS.
     * Jika belum pernah diizinkan, Android akan memunculkan dialog modal resmi:
     * "Kizen ingin menyiapkan koneksi VPN yang memungkinkannya memantau lalu lintas jaringan...
     * Ikon kunci [🔑] akan muncul di bagian atas layar Anda saat VPN aktif."
     */
    fun startVpnWithPermission(provider: String, result: MethodChannel.Result) {
        pendingProvider = provider
        val intent = VpnService.prepare(this)
        if (intent != null) {
            pendingVpnResult = result
            startActivityForResult(intent, REQUEST_VPN_PERMISSION)
        } else {
            // Sudah diizinkan oleh sistem sebelumnya
            startVpnService(provider)
            result.success(true)
        }
    }

    fun stopVpn(result: MethodChannel.Result) {
        val intent = Intent(this, KizenVpnService::class.java).apply {
            action = KizenVpnService.ACTION_STOP
        }
        startService(intent)
        result.success(true)
    }

    private fun startVpnService(provider: String) {
        val intent = Intent(this, KizenVpnService::class.java).apply {
            action = KizenVpnService.ACTION_START
            putExtra("provider", provider)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(this, intent)
        } else {
            startService(intent)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_VPN_PERMISSION) {
            val pending = pendingVpnResult
            pendingVpnResult = null
            if (resultCode == Activity.RESULT_OK) {
                startVpnService(pendingProvider)
                pending?.success(true)
            } else {
                pending?.success(false)
            }
        }
    }

    companion object {
        const val REQUEST_VPN_PERMISSION = 7701
    }
}
