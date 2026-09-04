/// file_service.dart — مجلد التطبيق على الهاتف: حفظ PDF والنسخ الاحتياطية | كيف الضيافة
///
/// البنية على الهاتف:
///   Documents/كيف الضيافة/
///     ├── الفواتير/2026/INV-0001.pdf
///     ├── عروض الأسعار/2026/QUO-0001.pdf
///     ├── كشوف الحساب/2026/SOA-202601-123.pdf
///     ├── سندات القبض/2026/REC-0001.pdf
///     └── النسخ الاحتياطية/keif-diafa-backup-2026-01-01.json
///
/// إن تعذّر الوصول إلى مجلد Documents العام (صلاحيات/إصدار أندرويد قديم) يُستخدم
/// مجلد التطبيق الخارجي `Android/data/<package>/files` تلقائيًا.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

enum FileKind { invoice, quote, statement, receipt, backup }

extension FileKindX on FileKind {
  String get folder => switch (this) {
        FileKind.invoice => 'الفواتير',
        FileKind.quote => 'عروض الأسعار',
        FileKind.statement => 'كشوف الحساب',
        FileKind.receipt => 'سندات القبض',
        FileKind.backup => 'النسخ الاحتياطية',
      };

  /// المستندات تُرتَّب داخل مجلد السنة؛ النسخ الاحتياطية لا
  bool get byYear => this != FileKind.backup;
}

class SavedFile {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final FileKind kind;
  const SavedFile({required this.path, required this.name, required this.size, required this.modified, required this.kind});

  String get sizeLabel => size < 1024
      ? '$size B'
      : size < 1024 * 1024
          ? '${(size / 1024).toStringAsFixed(0)} KB'
          : '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
}

class FileService {
  static const appFolder = 'كيف الضيافة';

  static Directory? _base;
  static bool _resolved = false;

  /// وصف مقروء لمكان المجلد (يظهر في الإعدادات)
  static String? get basePath => _base?.path;

  /// هل الميزة متاحة على هذه المنصة؟ (غير متاحة على الويب)
  static bool get supported => !kIsWeb;

  /// يحدد المجلد الأساسي مرة واحدة ويُنشئه إن لم يكن موجودًا
  static Future<Directory?> base() async {
    if (!supported) return null;
    if (_resolved) return _base;
    _resolved = true;
    _base = await _resolveBase();
    return _base;
  }

  /// إعادة المحاولة (مثلًا بعد منح الصلاحية)
  static Future<Directory?> refresh() async {
    _resolved = false;
    return base();
  }

  static Future<Directory?> _resolveBase() async {
    final candidates = <Future<Directory?> Function()>[
      _publicDocuments,
      _appExternal,
      () async => Directory('${(await getApplicationDocumentsDirectory()).path}/$appFolder'),
    ];
    for (final c in candidates) {
      try {
        final d = await c();
        if (d == null) continue;
        await d.create(recursive: true);
        // اختبار كتابة فعلي: بعض الإصدارات تسمح بإنشاء المجلد دون الكتابة فيه
        final probe = File('${d.path}/.probe');
        await probe.writeAsString('ok', flush: true);
        await probe.delete();
        return d;
      } catch (e) {
        debugPrint('FileService: candidate failed: $e');
      }
    }
    return null;
  }

  /// Documents العام على أندرويد: /storage/emulated/0/Documents/كيف الضيافة
  static Future<Directory?> _publicDocuments() async {
    if (!Platform.isAndroid) return null;
    // على أندرويد ≤ 10 نحتاج صلاحية التخزين؛ على 11+ يُسمح بالكتابة في Documents مباشرة
    try {
      final st = await Permission.storage.status;
      if (!st.isGranted) await Permission.storage.request();
    } catch (_) {}
    final ext = await getExternalStorageDirectory(); // .../Android/data/<pkg>/files
    if (ext == null) return null;
    final i = ext.path.indexOf('/Android/');
    if (i < 0) return null;
    final root = ext.path.substring(0, i); // /storage/emulated/0
    return Directory('$root/Documents/$appFolder');
  }

  static Future<Directory?> _appExternal() async {
    if (!Platform.isAndroid) return null;
    final ext = await getExternalStorageDirectory();
    if (ext == null) return null;
    return Directory('${ext.path}/$appFolder');
  }

  /// مجلد النوع (مع مجلد السنة للمستندات)
  static Future<Directory?> dirFor(FileKind kind, {String? year}) async {
    final b = await base();
    if (b == null) return null;
    var p = '${b.path}/${kind.folder}';
    if (kind.byYear) p += '/${year ?? DateTime.now().year.toString()}';
    final d = Directory(p);
    await d.create(recursive: true);
    return d;
  }

  /// يحفظ PDF ويعيد المسار الكامل (أو null على الويب/عند الفشل)
  static Future<String?> savePdf(Uint8List bytes, FileKind kind, String fileName, {String? year}) async {
    try {
      final d = await dirFor(kind, year: year);
      if (d == null) return null;
      final f = File('${d.path}/${safeName(fileName)}');
      await f.writeAsBytes(bytes, flush: true);
      return f.path;
    } catch (e) {
      debugPrint('FileService.savePdf failed: $e');
      return null;
    }
  }

  /// يحفظ نسخة احتياطية JSON ويعيد المسار
  static Future<String?> saveBackup(String json, String fileName) async {
    try {
      final d = await dirFor(FileKind.backup);
      if (d == null) return null;
      final f = File('${d.path}/${safeName(fileName)}');
      // كتابة آمنة: ملف مؤقت ثم إعادة تسمية حتى لا تتلف النسخة عند انقطاع مفاجئ
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      if (await f.exists()) await f.delete();
      await tmp.rename(f.path);
      return f.path;
    } catch (e) {
      debugPrint('FileService.saveBackup failed: $e');
      return null;
    }
  }

  /// يحذف النسخ الاحتياطية التلقائية الأقدم ويبقي آخر [keep]
  static Future<void> pruneBackups({int keep = 14}) async {
    try {
      final all = (await list(FileKind.backup)).where((f) => f.name.startsWith('auto-')).toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));
      for (final f in all.skip(keep)) {
        await File(f.path).delete();
      }
    } catch (e) {
      debugPrint('FileService.pruneBackups failed: $e');
    }
  }

  /// قائمة الملفات المحفوظة لنوع معيّن (كل السنوات) — الأحدث أولًا
  static Future<List<SavedFile>> list(FileKind kind) async {
    final out = <SavedFile>[];
    try {
      final b = await base();
      if (b == null) return out;
      final d = Directory('${b.path}/${kind.folder}');
      if (!await d.exists()) return out;
      await for (final e in d.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        if (name.startsWith('.') || name.endsWith('.tmp')) continue;
        final st = await e.stat();
        out.add(SavedFile(path: e.path, name: name, size: st.size, modified: st.modified, kind: kind));
      }
      out.sort((a, b) => b.modified.compareTo(a.modified));
    } catch (e) {
      debugPrint('FileService.list failed: $e');
    }
    return out;
  }

  static Future<String> readText(String path) => File(path).readAsString();

  static Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  /// فتح الملف بالتطبيق الافتراضي (قارئ PDF …)
  static Future<String?> open(String path) async {
    final r = await OpenFilex.open(path);
    if (r.type == ResultType.done) return null;
    return switch (r.type) {
      ResultType.noAppToOpen => 'لا يوجد تطبيق لفتح هذا الملف. ثبّت قارئ PDF.',
      ResultType.fileNotFound => 'الملف غير موجود.',
      ResultType.permissionDenied => 'لا توجد صلاحية لفتح الملف.',
      _ => r.message,
    };
  }

  /// مشاركة ملف محفوظ مباشرة من مساره
  static Future<void> share(String path, {String? text, String? subject}) =>
      Share.shareXFiles([XFile(path)], text: text, subject: subject);

  /// سنة المستند من تاريخ ISO (yyyy-mm-dd)؛ السنة الحالية إن كان التاريخ غير صالح
  static String yearOf(String isoDate) {
    final m = RegExp(r'^(\d{4})').firstMatch(isoDate.trim());
    return m?.group(1) ?? DateTime.now().year.toString();
  }

  static String safeName(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();
}
