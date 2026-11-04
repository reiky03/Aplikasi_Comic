package com.reikypratama.aplikasi_komik

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import com.reikypratama.aplikasi_komik.extensions.ExtensionRuntimeBridge
import com.reikypratama.aplikasi_komik.vpn.KizenWireguardManager
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
            startWireguardTunnel(provider, result)
        }
    }

    fun stopVpn(result: MethodChannel.Result) {
        KizenWireguardManager.stopTunnel(this) { success ->
            result.success(success)
        }
    }

    private fun startWireguardTunnel(provider: String, result: MethodChannel.Result? = null) {
        KizenWireguardManager.startTunnel(this, provider) { success ->
            result?.success(success)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_VPN_PERMISSION) {
            val pending = pendingVpnResult
            pendingVpnResult = null
            if (resultCode == Activity.RESULT_OK) {
                startWireguardTunnel(pendingProvider, pending)
            } else {
                pending?.success(false)
            }
        }
    }

    companion object {
        const val REQUEST_VPN_PERMISSION = 7701
    }
}
