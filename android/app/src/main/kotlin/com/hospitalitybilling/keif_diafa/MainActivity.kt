package com.hospitalitybilling.keif_diafa

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // app.storage — رقم إصدار أندرويد: لتحديد طريقة طلب صلاحية التخزين (MANAGE_EXTERNAL_STORAGE على 11+)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.storage").setMethodCallHandler { call, result ->
            when (call.method) {
                "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                else -> result.notImplemented()
            }
        }

        // app.update — التحديث داخل التطبيق (UpdateService في Dart):
        //   info               -> { versionCode, versionName, abi, packageName, canInstall }
        //   canInstall         -> هل يُسمح لهذا التطبيق بتثبيت حزم من مصادر غير معروفة (أندرويد 8+)
        //   openInstallSettings-> يفتح شاشة «تثبيت التطبيقات غير المعروفة» لهذا التطبيق
        //   install(path)      -> يفتح مثبّت النظام على ملف APK داخل مساحة التطبيق (FileProvider)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.update").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "info" -> {
                        val pi = packageManager.getPackageInfo(packageName, 0)
                        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) pi.longVersionCode else @Suppress("DEPRECATION") pi.versionCode.toLong()
                        result.success(mapOf(
                            "versionCode" to code,
                            "versionName" to (pi.versionName ?: ""),
                            "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: ""),
                            // مجلد المكتبات الأصلية للـ APK المثبّت (…/lib/arm64 أو …/lib/arm) — يحدد أي APK نُنزّل
                            "nativeLibDir" to (applicationInfo.nativeLibraryDir ?: ""),
                            "abis" to Build.SUPPORTED_ABIS.toList(),
                            "packageName" to packageName,
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "canInstall" to canInstall(),
                        ))
                    }
                    "canInstall" -> result.success(canInstall())
                    "openInstallSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val i = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                        }
                        result.success(true)
                    }
                    "install" -> {
                        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path")
                        val f = File(path)
                        if (!f.exists()) throw IllegalStateException("file not found")
                        val uri = FileProvider.getUriForFile(this, "$packageName.update.fileprovider", f)
                        val i = Intent(Intent.ACTION_VIEW)
                        i.setDataAndType(uri, "application/vnd.android.package-archive")
                        i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("update", e.message, null)
            }
        }
    }

    private fun canInstall(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) packageManager.canRequestPackageInstalls() else true
}
