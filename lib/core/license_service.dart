/// license_service.dart — القفل عن بُعد (مفتاح إيقاف) | كيف الضيافة / أصول الضيافة
///
/// مستودع التحكم (عام): github.com/MoTechSys/diafa-apps — مجلد لكل تطبيق:
///   كيف الضيافة/license.json   و   أصول الضيافة/license.json
///   { "active": true|false, "code": "XXXX", "message": "..." }
///
/// القواعد (مطابقة لمشروع Flutter-Native-App-022 مع تحسينات):
/// - active=true        => يفتح فورًا بلا كود (ويُمسح أي قفل سابق)
/// - active=false       => يُقفل ويطلب كود التفعيل؛ إذا طابق "code" في الملف
///                         يُحفظ ويفتح ما دام نفس الكود في الملف (تغييره = قفل من جديد)
/// - الملف محذوف (404)  => قفل كامل ولا يُقبل أي كود (فقط إن سبق للتطبيق رؤية
///                         الملف مرة — حتى لا يُقفل قبل رفع الملف)
/// - لا إنترنت          => آخر حالة معروفة (أول تشغيل بلا إنترنت مسموح)
///
/// البيانات لا تُمس أبدًا: القفل يمنع الدخول للواجهة فقط.
/// الفحص عند التشغيل + عند الرجوع للتطبيق (كل 10 دقائق كحد أدنى) فيُقفل
/// خلال دقائق من تغيير الملف حتى لو التطبيق مفتوح.
///
/// الكاش: raw.githubusercontent يمر عبر CDN (حتى 5 دقائق)، لذلك المصدر
/// الأساسي GitHub API (بلا كاش)، وعند فشله (حد 60 طلب/ساعة) نرجع للملف الخام.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'brand.dart';

class LicenseState {
  final bool allowed;
  final String message;

  /// هل يوجد كود يمكن قبوله أصلًا (false عند حذف الملف)
  final bool codeAccepted;
  final bool offline;
  const LicenseState({
    required this.allowed,
    this.message = '',
    this.codeAccepted = true,
    this.offline = false,
  });
}

class LicenseService extends ChangeNotifier {
  /// عميل HTTP قابل للاستبدال (للاختبارات)
  static http.Client client = http.Client();

  static const owner = 'MoTechSys';
  static const repo = 'diafa-apps';

  /// المسار داخل المستودع: <اسم المجلد العربي>/license.json
  static List<String> get fileSegments => [
    Brand.current.folderName,
    'license.json',
  ];

  // Uri.https يرمّز الحروف العربية والمسافات بدقة
  static Uri get rawUri => Uri.https(
    'raw.githubusercontent.com',
    '/$owner/$repo/main/${fileSegments.join('/')}',
  );
  static Uri get apiUri => Uri.https(
    'api.github.com',
    '/repos/$owner/$repo/contents/${fileSegments.join('/')}',
    {'ref': 'main'},
  );

  // مفاتيح منفصلة لكل تطبيق
  static String get _p => 'lic_${Brand.current.id}_';
  static String get _kBlocked => '${_p}blocked';
  static String get _kMessage => '${_p}message';
  static String get _kCode => '${_p}code';
  static String get _kActivated => '${_p}activated_code';
  static String get _kDeleted => '${_p}deleted';
  static String get _kSeen => '${_p}seen';

  /// أقل فاصل بين فحصين تلقائيين عند الرجوع للتطبيق
  static const recheckEvery = Duration(minutes: 10);

  LicenseState? _state;
  DateTime? _lastCheck;
  bool _checking = false;

  LicenseState? get state => _state;
  bool get ready => _state != null;
  bool get allowed => _state?.allowed ?? true;

  /// الفحص الأول: يعرض آخر حالة محفوظة فورًا ثم يحدّثها من الشبكة
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _state = _fromCache(prefs);
    } catch (e) {
      // الويب داخل iframe مقيّد: localStorage يرمي SecurityError. لا نقفل التطبيق
      // بسبب تعذّر التخزين — نعرض الحالة الافتراضية (مسموح) ونكمل.
      debugPrint('LicenseService.init: prefs unavailable ($e)');
      _state = const LicenseState(
        allowed: true,
        message: '',
        codeAccepted: false,
      );
    }
    notifyListeners();
    await refresh();
  }

  /// فحص عند الرجوع للتطبيق (مع حد أدنى للفاصل)
  Future<void> onResumed() async {
    final last = _lastCheck;
    if (last != null && DateTime.now().difference(last) < recheckEvery) {
      return;
    }
    await refresh();
  }

  Future<LicenseState> refresh() async {
    if (_checking) return _state ?? const LicenseState(allowed: true);
    _checking = true;
    try {
      final st = await check();
      _lastCheck = DateTime.now();
      _state = st;
      notifyListeners();
      return st;
    } catch (e) {
      // تعذّر التخزين (ويب مقيّد) أو خطأ غير متوقع: نُبقي آخر حالة معروفة — لا قفل خاطئ
      debugPrint('LicenseService.refresh failed: $e');
      return _state ?? const LicenseState(allowed: true);
    } finally {
      _checking = false;
    }
  }

  Future<bool> unlock(String code) async {
    final ok = await activate(code);
    if (ok) {
      _state = const LicenseState(allowed: true);
      notifyListeners();
    }
    return ok;
  }

  /* ---------------- المنطق (ثابت/قابل للاختبار) ---------------- */

  static Future<LicenseState> check() async {
    final prefs = await SharedPreferences.getInstance();
    final remote = await _fetchRemote();

    if (remote == null) return _fromCache(prefs, offline: true);

    if (remote.notFound) {
      // أمان: لا نقفل بسبب ملف لم يُرفع بعد — الحذف يقفل فقط إن سبق رؤية الملف
      if (!(prefs.getBool(_kSeen) ?? false)) {
        return _fromCache(prefs, offline: true);
      }
      const msg = 'انتهى ترخيص هذه النسخة. يرجى التواصل مع المطوّر.';
      await prefs.setBool(_kBlocked, true);
      await prefs.setBool(_kDeleted, true);
      await prefs.setString(_kMessage, msg);
      await prefs.setString(_kCode, '');
      return const LicenseState(
        allowed: false,
        message: msg,
        codeAccepted: false,
      );
    }

    final data = remote.data!;
    final active = data['active'] == true;
    final msg = (data['message'] ?? '').toString();
    final code = (data['code'] ?? '').toString().trim().toUpperCase();

    await prefs.setBool(_kSeen, true);
    await prefs.setBool(_kDeleted, false);
    await prefs.setString(_kMessage, msg);
    await prefs.setString(_kCode, code);

    if (active) {
      await prefs.setBool(_kBlocked, false);
      return LicenseState(allowed: true, message: msg);
    }

    final saved = (prefs.getString(_kActivated) ?? '').toUpperCase();
    final unlocked = code.isNotEmpty && saved == code;
    await prefs.setBool(_kBlocked, !unlocked);
    return LicenseState(
      allowed: unlocked,
      message: msg,
      codeAccepted: code.isNotEmpty,
    );
  }

  static LicenseState _fromCache(
    SharedPreferences prefs, {
    bool offline = false,
  }) {
    final blocked = prefs.getBool(_kBlocked) ?? false;
    final deleted = prefs.getBool(_kDeleted) ?? false;
    return LicenseState(
      allowed: !blocked,
      message: prefs.getString(_kMessage) ?? '',
      codeAccepted: !deleted && (prefs.getString(_kCode) ?? '').isNotEmpty,
      offline: offline,
    );
  }

  /// التحقق من الكود مقابل الملف؛ عند النجاح يُحفظ ويفتح
  static Future<bool> activate(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final remote = await _fetchRemote();
    if (remote != null && remote.notFound) return false;
    if (remote?.data != null) {
      await prefs.setString(
        _kCode,
        (remote!.data!['code'] ?? '').toString().trim().toUpperCase(),
      );
    }
    final code = prefs.getString(_kCode) ?? '';
    if (code.isEmpty) return false;
    final ok = input.trim().toUpperCase() == code;
    if (ok) {
      await prefs.setString(_kActivated, code);
      await prefs.setBool(_kBlocked, false);
    }
    return ok;
  }

  // ---------------- جلب الملف بدون كاش ----------------
  static const Map<String, String> _noCache = {
    'Cache-Control': 'no-cache, no-store, max-age=0',
    'Pragma': 'no-cache',
  };

  static Future<_Remote?> _fetchRemote() async {
    final api = await _fetchApi();
    if (api != null) return api;
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final u = rawUri.replace(queryParameters: {'nocache': '$ts'});
      final res = await client
          .get(u, headers: _noCache)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return _Remote(_decode(_utf8(res)));
      if (res.statusCode == 404) return _Remote.notFound();
    } catch (_) {}
    return null;
  }

  static Future<_Remote?> _fetchApi() async {
    try {
      final res = await client
          .get(
            apiUri,
            headers: {..._noCache, 'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final meta = jsonDecode(_utf8(res)) as Map<String, dynamic>;
        final b64 = (meta['content'] ?? '').toString().replaceAll(
          RegExp(r'\s'),
          '',
        );
        if (b64.isNotEmpty) {
          return _Remote(_decode(utf8.decode(base64Decode(b64))));
        }
      }
      if (res.statusCode == 404) return _Remote.notFound();
    } catch (_) {}
    return null; // 403 (حد الطلبات) أو فشل => الملف الخام
  }

  static String _utf8(http.Response res) => utf8.decode(res.bodyBytes);

  /// ملف تالف (JSON غير صالح) لا يُقفل التطبيق خطأً: يُعامل كانقطاع
  static Map<String, dynamic> _decode(String body) {
    final v = jsonDecode(body);
    if (v is Map<String, dynamic>) return v;
    throw const FormatException('license: not an object');
  }
}

class _Remote {
  final Map<String, dynamic>? data;
  final bool notFound;
  _Remote(this.data) : notFound = false;
  _Remote.notFound() : data = null, notFound = true;
}
