/// backup_service.dart — النسخ الاحتياطي المُتحقَّق منه (الجهاز + Google Drive) | نظام الفواتير
///
/// ضمانات كل نسخة:
///  1. **بصمة SHA-256** لمحتوى البيانات داخل الملف (`sha256`) — أي تلف أو تعديل يُكتشف عند الاسترجاع.
///  2. **كتابة ذرّية**: ملف مؤقت → flush → إعادة تسمية؛ انقطاع مفاجئ لا يترك نسخة نصف مكتوبة.
///  3. **قراءة تحققية** بعد الكتابة: يُعاد فتح الملف ويُعاد حساب البصمة ومقارنة الأعداد.
///     إن لم تتطابق يُحذف الملف وتُعاد المحاولة مرة، ثم يُبلَّغ بالفشل (لا نسخة «ناجحة» مزيّفة).
///  4. **نسخة يومية** تلقائية: عند أول فتح في اليوم + بعد كل تعديل (يُستبدل ملف اليوم نفسه).
///     يُحتفظ بآخر [keepDaily] يومًا، والنسخ اليدوية لا تُحذف تلقائيًا أبدًا.
///  5. نسخة Google Drive (إن فُعّلت) تُرفع مرة يوميًا ويُقارن md5 المرفوع بالمحلي.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'brand.dart';
import 'drive_service.dart';
import 'file_service.dart';
import 'models.dart';
import 'store.dart';

/// نتيجة التحقق من ملف نسخة
class BackupCheck {
  final bool ok;
  final String message;
  final Map<String, int> counts;
  final bool hasHash;
  const BackupCheck(
    this.ok,
    this.message, {
    this.counts = const {},
    this.hasHash = false,
  });
}

class BackupService {
  static const schema = 4;
  static const keepDaily = 30;

  /// ترميز ثابت (مفاتيح مرتّبة) حتى تكون البصمة قابلة لإعادة الحساب بدقة
  static String canonical(Object? v) => jsonEncode(_sorted(v));
  static Object? _sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return {for (final k in keys) k: _sorted(v[k])};
    }
    if (v is List) return v.map(_sorted).toList();
    return v;
  }

  static String hashData(Object? data) =>
      sha256.convert(utf8.encode(canonical(data))).toString();

  /// ملف النسخة الكامل (غلاف + بيانات + بصمة)
  static String encode(Store s) {
    final data = s.exportData();
    return const JsonEncoder.withIndent(null).convert({
      'app': Brand.current.backupAppTag,
      'brand': Brand.current.id,
      'schema': schema,
      'exportedAt': DateTime.now().toIso8601String(),
      'counts': s.counts,
      'sha256': hashData(data),
      'data': data,
    });
  }

  /// فحص ملف نسخة قبل الاسترجاع: صيغة + بصمة + نسخة التطبيق الصحيحة
  static BackupCheck verify(String text) {
    Object? m;
    try {
      m = jsonDecode(text);
    } catch (_) {
      return const BackupCheck(
        false,
        'الملف ليس نسخة احتياطية صالحة (JSON تالف).',
      );
    }
    if (m is! Map || m['data'] is! Map) {
      return const BackupCheck(
        false,
        'الملف ليس نسخة احتياطية من هذا التطبيق.',
      );
    }
    final data = m['data'] as Map;
    final app = '${m['app'] ?? ''}';
    // نسخ الإصدارات القديمة: keif-diafa بلا brand
    final brand = '${m['brand'] ?? (app == 'keif-diafa' ? 'keif' : '')}';
    if (brand.isNotEmpty && brand != Brand.current.id) {
      final other =
          Brand.all.where((b) => b.id == brand).firstOrNull?.appName ?? brand;
      return BackupCheck(
        false,
        'هذه النسخة تخص تطبيق «$other» وليست لـ«${Brand.current.appName}». لا يمكن خلط بيانات المؤسستين.',
      );
    }
    int n(String k) => (data[k] as List?)?.length ?? 0;
    final counts = {
      'clients': n('clients'),
      'docs': n('docs') + n('invoices'),
      'payments': n('payments'),
      'claims': n('claims'),
    };
    final h = m['sha256'];
    if (h is String && h.isNotEmpty) {
      if (hashData(data) != h) {
        return BackupCheck(
          false,
          'فشل التحقق: بصمة الملف لا تطابق محتواه — الملف تالف أو معدّل. استخدم نسخة أخرى.',
          counts: counts,
          hasHash: true,
        );
      }
      return BackupCheck(
        true,
        'سليمة ومُتحقَّق منها (SHA-256)',
        counts: counts,
        hasHash: true,
      );
    }
    return BackupCheck(
      true,
      'نسخة قديمة بلا بصمة — تُسترجع بعد فحص الصيغة فقط',
      counts: counts,
    );
  }

  static String _fileName({required bool auto, DateTime? at}) {
    final p = Brand.current.backupPrefix;
    return auto
        ? '$p-auto-${todayISO()}.json'
        : '$p-backup-${Store.backupStamp(at)}.json';
  }

  /// كتابة نسخة إلى مجلد الهاتف مع قراءة تحققية. تعيد المسار أو null
  static Future<String?> writeLocal(Store s, {required bool auto}) async {
    if (!FileService.supported) return null;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final text = encode(s);
        final path = await FileService.saveBackup(text, _fileName(auto: auto));
        if (path == null) return null;
        final back = await FileService.readText(path);
        final chk = verify(back);
        if (chk.ok && chk.hasHash && back.length == text.length) {
          await s.setKv('lastBackupHash', jsonDecode(back)['sha256']);
          if (auto) {
            await s.setKv('lastDailyBackup', todayISO());
            await FileService.pruneBackups(keep: keepDaily);
          }
          return path;
        }
        debugPrint(
          'BackupService: read-back verification failed (attempt $attempt): ${chk.message}',
        );
        await FileService.delete(path);
      } catch (e) {
        debugPrint('BackupService.writeLocal failed (attempt $attempt): $e');
      }
    }
    return null;
  }

  /// النسخة اليومية: تُكتب مرة عند أول فتح في اليوم، ثم تُرفع إلى Drive إن كان مفعّلًا
  static Future<void> dailyIfDue(Store s) async {
    try {
      if (!FileService.supported || s.isEmpty) return;
      if (s.autoBackupEnabled && s.kv('lastDailyBackup') != todayISO()) {
        await s.backupNow(auto: true);
      }
      await DriveService.dailyIfDue(s);
    } catch (e) {
      debugPrint('BackupService.dailyIfDue: $e');
    }
  }
}
