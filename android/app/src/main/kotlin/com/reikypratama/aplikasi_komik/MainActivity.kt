package com.reikypratama.aplikasi_komik

import com.reikypratama.aplikasi_komik.extensions.ExtensionRuntimeBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ExtensionRuntimeBridge(this).register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
