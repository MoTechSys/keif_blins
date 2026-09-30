/// update_service.dart — التحديث داخل التطبيق من GitHub (مثل مفتاح القفل عن بُعد) | نظام الفواتير
///
/// المصدر (عام): github.com/MoTechSys/diafa-apps — بجوار license.json في مجلد كل تطبيق:
///   كيف الضيافة/update.json   و   أصول الضيافة/update.json
///
/// صيغة الملف (ADR-0005):
/// ```json
/// {
///   "version": "2.6.0",
///   "build": 2600,
///   "versionCodes": { "arm64": 4600, "armv7": 3600 },
///   "apks": {
///     "arm64": { "url": "https://github.com/MoTechSys/diafa-apps/releases/download/v2.6.0/keif-aldiafa-v2.6.0-arm64.apk",
///                "sha256": "…64 hex…", "size": 12345678 },
///     "armv7": { "url": "…-armv7.apk", "sha256": "…", "size": 11223344 }
///   },
///   "notes": "ما الجديد (يظهر للمستخدم)",
///   "publishedAt": "2026-09-30",
///   "minSupportedBuild": 2500
/// }
/// ```
///
/// المنطق:
///  1. نعرف نسخة الـ APK المثبّتة (versionCode) ومعماريتها من `nativeLibraryDir`
///     (…/lib/arm64 أو …/lib/arm) — لا من معمارية الجهاز، لأن المستخدم قد يثبّت armv7 على جهاز arm64.
///  2. تحديث متاح ⇔ versionCodes[<معماريتي>] > versionCode المثبّت.
///  3. التنزيل إلى cache/updates/<اسم>.apk مع تقدّم، ثم **تحقق SHA-256** إلزامي (ملف لا يطابق = يُحذف ويُرفض).
///  4. التثبيت عبر مثبّت النظام (FileProvider) — أندرويد 8+ يطلب أولًا السماح بـ«تثبيت تطبيقات غير معروفة»
///     لهذا التطبيق؛ نفتح الشاشة المناسبة مباشرة ونعيد المحاولة بعد الرجوع.
///  5. الفحص التلقائي: عند التشغيل مرة كل 24 ساعة (kv lastUpdateCheck) + زر يدوي في الإعدادات.
///     إن تخطّى المستخدم إصدارًا (kv updateSkippedCode) لا نزعجه به تلقائيًا مرة أخرى.
///
/// الأمان: نفس مفتاح التوقيع دائمًا (diafa-signing-keys) — أندرويد نفسه يرفض APK بمفتاح مختلف؛
/// وSHA-256 من الملف يمنع تثبيت ملف منزَّل ناقص/معدّل. الملف يُقرأ عبر GitHub API (بلا كاش) ثم الخام.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'brand.dart';

/// وصف تحديث منشور (من update.json)
class UpdateInfo {
  final String version;
  final int build;
  final Map<String, int> versionCodes; // abi -> versionCode
  final Map<String, UpdateApk> apks; // abi -> apk
  final String notes;
  final String publishedAt;
  final int minSupportedBuild;
  const UpdateInfo({
    required this.version,
    required this.build,
    required this.versionCodes,
    required this.apks,
    this.notes = '',
    this.publishedAt = '',
    this.minSupportedBuild = 0,
  });

  static UpdateInfo? tryParse(Object? v) {
    if (v is! Map) return null;
    try {
      int i(Object? x) => x is num ? x.toInt() : int.parse('$x');
      final vc = <String, int>{};
      (v['versionCodes'] as Map?)?.forEach((k, x) => vc['$k'] = i(x));
      final apks = <String, UpdateApk>{};
      (v['apks'] as Map?)?.forEach((k, x) {
        final a = UpdateApk.tryParse(x);
        if (a != null) apks['$k'] = a;
      });
      final version = '${v['version'] ?? ''}'.trim();
      if (version.isEmpty || vc.isEmpty || apks.isEmpty) return null;
      return UpdateInfo(
        version: version,
        build: i(v['build'] ?? 0),
        versionCodes: vc,
        apks: apks,
        notes: '${v['notes'] ?? ''}',
        publishedAt: '${v['publishedAt'] ?? ''}',
        minSupportedBuild: i(v['minSupportedBuild'] ?? 0),
      );
    } catch (_) {
      return null;
    }
  }
}

class UpdateApk {
  final Uri url;
  final String sha256; // hex صغير
  final int size;
  const UpdateApk({required this.url, required this.sha256, this.size = 0});

  static UpdateApk? tryParse(Object? v) {
    if (v is! Map) return null;
    final u = Uri.tryParse('${v['url'] ?? ''}');
    final h = '${v['sha256'] ?? ''}'.trim().toLowerCase();
    if (u == null || !u.hasScheme || !RegExp(r'^[0-9a-f]{64}$').hasMatch(h)) {
      return null;
    }
    final s = v['size'];
    return UpdateApk(url: u, sha256: h, size: s is num ? s.toInt() : 0);
  }
}

/// حالة التطبيق المثبّت (من الكود الأصلي)
class InstalledInfo {
  final int versionCode;
  final String versionName;
  final String abi; // arm64 | armv7 | x86_64 | ''
  final bool canInstall;
  final int sdkInt;
  const InstalledInfo({
    required this.versionCode,
    required this.versionName,
    required this.abi,
    required this.canInstall,
    required this.sdkInt,
  });
}

/// نتيجة الفحص
enum UpdateStatus { upToDate, available, offline, invalid, unsupported }

class UpdateCheck {
  final UpdateStatus status;
  final UpdateInfo? info;
  final InstalledInfo? installed;
  final String message;
  const UpdateCheck(
    this.status, {
    this.info,
    this.installed,
    this.message = '',
  });
  bool get available => status == UpdateStatus.available;

  /// الـ APK المناسب لمعمارية التطبيق المثبّت
  UpdateApk? get apk => info?.apks[installed?.abi ?? ''];
}

class UpdateService extends ChangeNotifier {
  /// عميل HTTP قابل للاستبدال (للاختبارات)
  static http.Client client = http.Client();

  /// قناة الكود الأصلي قابلة للاستبدال (للاختبارات)
  @visibleForTesting
  static Future<dynamic> Function(String method, [dynamic args])? debugInvoke;

  static const owner = 'MoTechSys';
  static const repo = 'diafa-apps';
  static const _ch = MethodChannel('app.update');
  static const checkEvery = Duration(hours: 24);

  static List<String> get fileSegments => [
    Brand.current.folderName,
    'update.json',
  ];
  static Uri get rawUri => Uri.https(
    'raw.githubusercontent.com',
    '/$owner/$repo/main/${fileSegments.join('/')}',
  );
  static Uri get apiUri => Uri.https(
    'api.github.com',
    '/repos/$owner/$repo/contents/${fileSegments.join('/')}',
    {'ref': 'main'},
  );

  UpdateCheck? last;
  bool checking = false;

  /// تقدّم التنزيل 0..1 (null = لا تنزيل جارٍ)
  final ValueNotifier<double?> progress = ValueNotifier(null);

  /// هل الميزة متاحة (أندرويد فقط)
  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<dynamic> _invoke(String m, [dynamic args]) =>
      debugInvoke != null ? debugInvoke!(m, args) : _ch.invokeMethod(m, args);

  /// معلومات التطبيق المثبّت (null إن تعذّر — ويب/اختبار بلا قناة)
  static Future<InstalledInfo?> installed() async {
    try {
      final m = await _invoke('info');
      if (m is! Map) return null;
      return InstalledInfo(
        versionCode: (m['versionCode'] as num?)?.toInt() ?? 0,
        versionName: '${m['versionName'] ?? ''}',
        abi: abiKey('${m['nativeLibDir'] ?? ''}', '${m['abi'] ?? ''}'),
        canInstall: m['canInstall'] == true,
        sdkInt: (m['sdkInt'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('UpdateService.installed: $e');
      return null;
    }
  }

  /// مفتاح المعمارية من مجلد المكتبات الأصلية للـ APK المثبّت (الأدق)، وإلا من معمارية الجهاز
  static String abiKey(String nativeLibDir, String deviceAbi) {
    final d = nativeLibDir.split('/').where((s) => s.isNotEmpty).lastOrNull;
    switch (d) {
      case 'arm64':
        return 'arm64';
      case 'arm':
        return 'armv7';
      case 'x86_64':
        return 'x86_64';
      case 'x86':
        return 'x86';
    }
    switch (deviceAbi) {
      case 'arm64-v8a':
        return 'arm64';
      case 'armeabi-v7a':
      case 'armeabi':
        return 'armv7';
      case 'x86_64':
        return 'x86_64';
      case 'x86':
        return 'x86';
    }
    return '';
  }

  /// المقارنة الصرفة (قابلة للاختبار بلا جهاز)
  static UpdateCheck compare(UpdateInfo? info, InstalledInfo? inst) {
    if (info == null) {
      return const UpdateCheck(
        UpdateStatus.invalid,
        message: 'ملف التحديث غير صالح',
      );
    }
    if (inst == null || inst.abi.isEmpty) {
      return UpdateCheck(
        UpdateStatus.unsupported,
        info: info,
        installed: inst,
        message: 'تعذّر تحديد نسخة التطبيق المثبّتة',
      );
    }
    final target = info.versionCodes[inst.abi];
    final apk = info.apks[inst.abi];
    if (target == null || apk == null) {
      return UpdateCheck(
        UpdateStatus.unsupported,
        info: info,
        installed: inst,
        message: 'لا يوجد إصدار لهذه المعمارية (${inst.abi})',
      );
    }
    if (target > inst.versionCode) {
      return UpdateCheck(
        UpdateStatus.available,
        info: info,
        installed: inst,
        message: 'الإصدار ${info.version} متاح',
      );
    }
    return UpdateCheck(
      UpdateStatus.upToDate,
      info: info,
      installed: inst,
      message: 'لديك آخر إصدار (${inst.versionName})',
    );
  }

  /// فحص كامل: جلب الملف + مقارنة. لا يرمي — يعيد offline عند تعذّر الشبكة
  Future<UpdateCheck> check() async {
    if (checking) return last ?? const UpdateCheck(UpdateStatus.offline);
    checking = true;
    notifyListeners();
    try {
      final inst = await installed();
      final remote = await fetchRemote();
      if (remote == null) {
        last = UpdateCheck(
          UpdateStatus.offline,
          installed: inst,
          message: 'لا يمكن الوصول إلى خادم التحديث الآن',
        );
      } else {
        last = compare(UpdateInfo.tryParse(remote), inst);
      }
      return last!;
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  /// هل حان الفحص التلقائي؟ (مرة كل 24 ساعة)
  static bool isCheckDue(Object? lastIso, {DateTime? now}) {
    final t = DateTime.tryParse('${lastIso ?? ''}');
    if (t == null) return true;
    return (now ?? DateTime.now()).difference(t) >= checkEvery;
  }

  /* ---------------- التنزيل والتثبيت ---------------- */

  /// مجلد التنزيل داخل كاش التطبيق (يطابق res/xml/update_paths.xml)
  static Future<Directory> _dir() async {
    final c = await getTemporaryDirectory();
    final d = Directory('${c.path}/updates');
    await d.create(recursive: true);
    return d;
  }

  /// ينزّل الـ APK ويتحقق من SHA-256. يعيد المسار أو يرمي [UpdateException]
  Future<String> download(UpdateApk apk, {String? fileName}) async {
    final d = await _dir();
    final name = fileName ?? apk.url.pathSegments.last;
    final f = File('${d.path}/$name');
    // ملف سابق سليم؟ لا نعيد التنزيل
    if (await f.exists() && await sha256File(f) == apk.sha256) return f.path;
    progress.value = 0;
    try {
      final req = http.Request('GET', apk.url);
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw UpdateException('فشل التنزيل (HTTP ${res.statusCode})');
      }
      final total = res.contentLength ?? apk.size;
      final sink = f.openWrite();
      var got = 0;
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) progress.value = (got / total).clamp(0, 1);
        }
      } finally {
        await sink.close();
      }
      final h = await sha256File(f);
      if (h != apk.sha256) {
        await f.delete();
        throw UpdateException(
          'الملف المنزَّل لا يطابق البصمة المنشورة — أُلغي التثبيت حمايةً لك. أعد المحاولة.',
        );
      }
      return f.path;
    } on UpdateException {
      rethrow;
    } catch (e) {
      if (await f.exists()) await f.delete();
      throw UpdateException('تعذّر التنزيل: تحقّق من الاتصال بالإنترنت');
    } finally {
      progress.value = null;
    }
  }

  static Future<String> sha256File(File f) async {
    final digest = await sha256.bind(f.openRead()).first;
    return digest.toString();
  }

  /// هل يُسمح لهذا التطبيق بتثبيت حزم؟ (أندرويد 8+)
  static Future<bool> canInstall() async {
    try {
      return await _invoke('canInstall') == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openInstallSettings() async {
    try {
      await _invoke('openInstallSettings');
    } catch (e) {
      debugPrint('openInstallSettings: $e');
    }
  }

  /// يفتح مثبّت النظام على الملف
  static Future<void> install(String path) async {
    try {
      await _invoke('install', {'path': path});
    } on PlatformException catch (e) {
      throw UpdateException('تعذّر فتح المثبّت: ${e.message}');
    }
  }

  /// حذف ملفات التحديث القديمة (بعد نجاح التثبيت تُستدعى عند التشغيل التالي)
  static Future<void> cleanup() async {
    try {
      final d = await _dir();
      await for (final e in d.list()) {
        if (e is File) await e.delete();
      }
    } catch (_) {}
  }

  /* ---------------- جلب الملف بدون كاش (نفس نهج LicenseService) ---------------- */
  static const Map<String, String> _noCache = {
    'Cache-Control': 'no-cache, no-store, max-age=0',
    'Pragma': 'no-cache',
  };

  /// يعيد JSON الملف أو null عند تعذّر الشبكة/404
  static Future<Map<String, dynamic>?> fetchRemote() async {
    try {
      final res = await client
          .get(
            apiUri,
            headers: {..._noCache, 'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final meta =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final b64 = '${meta['content'] ?? ''}'.replaceAll(RegExp(r'\s'), '');
        if (b64.isNotEmpty) {
          final v = jsonDecode(utf8.decode(base64Decode(b64)));
          if (v is Map<String, dynamic>) return v;
        }
      }
      if (res.statusCode == 404) return null;
    } catch (_) {}
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final res = await client
          .get(
            rawUri.replace(queryParameters: {'nocache': '$ts'}),
            headers: _noCache,
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final v = jsonDecode(utf8.decode(res.bodyBytes));
        if (v is Map<String, dynamic>) return v;
      }
    } catch (_) {}
    return null;
  }
}

class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);
  @override
  String toString() => message;
}
