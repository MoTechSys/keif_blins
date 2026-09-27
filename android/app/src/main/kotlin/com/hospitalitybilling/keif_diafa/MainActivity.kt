package com.hospitalitybilling.keif_diafa

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // رقم إصدار أندرويد: لتحديد طريقة طلب صلاحية التخزين (MANAGE_EXTERNAL_STORAGE على 11+)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.storage").setMethodCallHandler { call, result ->
            when (call.method) {
                "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                else -> result.notImplemented()
            }
        }
    }
}
