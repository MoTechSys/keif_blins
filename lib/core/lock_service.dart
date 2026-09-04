/// lock_service.dart — قفل التطبيق برمز PIN | كيف الضيافة
///
/// - الرمز لا يُخزَّن أبدًا كنص؛ يُخزَّن SHA-256 مع Salt عشوائي وتكرار 20,000 مرة
/// - يُحفظ في صندوق Hive منفصل (keif_diafa_secure) حتى لا يمسحه "مسح جميع البيانات"
/// - يُقفل عند التشغيل وعند الرجوع من الخلفية بعد مهلة قصيرة
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LockService extends ChangeNotifier {
  static const _boxName = 'keif_diafa_secure';
  static const _iterations = 20000;

  /// مهلة إعادة القفل بعد ترك التطبيق (ثوانٍ)
  static const relockAfterSeconds = 30;

  Box? _box;
  bool _locked = false;
  bool _inited = false;

  LockService();

  /// للاختبارات: صندوق مفتوح مسبقًا
  @visibleForTesting
  LockService.withBox(Box box) : _box = box, _inited = true;

  /// اكتملت التهيئة (لتفادي ظهور التطبيق لحظة قبل شاشة القفل)
  bool get initialized => _inited;
  DateTime? _pausedAt;
  int _failed = 0;

  bool get enabled => (_box?.get('hash') as String?)?.isNotEmpty ?? false;
  bool get locked => _locked;
  int get failedAttempts => _failed;

  /// وقت الانتظار المطلوب بعد محاولات فاشلة متكررة (ثوانٍ)
  int get cooldownSeconds {
    if (_failed < 5) return 0;
    final until = _box?.get('cooldownUntil') as int?;
    if (until == null) return 0;
    final left = (until - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
    return left > 0 ? left : 0;
  }

  Future<void> init() async {
    try {
      // آمن عند التكرار: يحدد مسار Hive فقط
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
      _failed = (_box!.get('failed') as int?) ?? 0;
      _locked = enabled;
    } catch (e) {
      debugPrint('LockService.init failed: $e');
      _locked = false;
    }
    _inited = true;
    notifyListeners();
  }

  /* ---------- دورة حياة التطبيق ---------- */
  void onPaused() => _pausedAt = DateTime.now();

  void onResumed() {
    if (!enabled || _locked) return;
    final p = _pausedAt;
    if (p != null && DateTime.now().difference(p).inSeconds >= relockAfterSeconds) {
      _locked = true;
      notifyListeners();
    }
  }

  /* ---------- الرمز ---------- */
  static bool isValidPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  String _hash(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < _iterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64.encode(bytes);
  }

  String _newSalt() {
    final r = Random.secure();
    return base64.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('الرمز يجب أن يكون من 4 إلى 6 أرقام');
    final b = _box;
    if (b == null) throw StateError('تعذّر الوصول إلى صندوق الحماية');
    final salt = _newSalt();
    await b.put('salt', salt);
    await b.put('hash', _hash(pin, salt));
    await b.put('failed', 0);
    _failed = 0;
    notifyListeners();
  }

  Future<void> disable() async {
    await _box?.delete('hash');
    await _box?.delete('salt');
    await _box?.delete('failed');
    await _box?.delete('cooldownUntil');
    _failed = 0;
    _locked = false;
    notifyListeners();
  }

  bool verify(String pin) {
    final b = _box;
    if (b == null) return false;
    final salt = b.get('salt') as String?;
    final hash = b.get('hash') as String?;
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }

  /// محاولة فتح القفل — تعيد true عند النجاح
  Future<bool> unlock(String pin) async {
    if (cooldownSeconds > 0) return false;
    if (verify(pin)) {
      _failed = 0;
      await _box?.put('failed', 0);
      await _box?.delete('cooldownUntil');
      _locked = false;
      notifyListeners();
      return true;
    }
    _failed++;
    await _box?.put('failed', _failed);
    if (_failed >= 5) {
      // انتظار متصاعد: 30ث، 60ث، 120ث …
      final secs = 30 * (1 << min(_failed - 5, 4));
      await _box?.put('cooldownUntil', DateTime.now().add(Duration(seconds: secs)).millisecondsSinceEpoch);
    }
    notifyListeners();
    return false;
  }

  void lockNow() {
    if (!enabled) return;
    _locked = true;
    notifyListeners();
  }
}
