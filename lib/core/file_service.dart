/// file_service.dart — مجلد التطبيق على الهاتف: حفظ PDF والنسخ الاحتياطية | نظام الفواتير
///
/// البنية في **جذر الذاكرة الداخلية** (مثل واتساب) — تُنشأ كلها فور تشغيل التطبيق:
///   /storage/emulated/0/<اسم التطبيق>/
///     ├── الفواتير/2026/فاتورة INV-0001 - العميل.pdf
///     ├── عروض الأسعار/2026/…
///     ├── خطابات المطالبة/2026/…
///     ├── كشوف الحساب/2026/…
///     ├── سندات القبض/2026/…
///     └── النسخ الاحتياطية/keif-auto-2026-09-27.json
///
/// أندرويد 11+ يتطلب «الوصول إلى كل الملفات» للكتابة في الجذر: يُطلب مرة واحدة من شاشة
/// الإعداد مع شرح. إن رفض المستخدم نستخدم `Documents/<اسم التطبيق>` (لا يحتاج صلاحية)،
/// ثم مجلد التطبيق الخارجي، ثم الداخلي — بترتيب ثابت، مع اختبار كتابة فعلي لكل مرشّح.
/// عند الانتقال من مسار قديم إلى الجذر تُنسخ الملفات القديمة تلقائيًا (دون حذف الأصل).
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'brand.dart';

enum FileKind { invoice, quote, claim, statement, receipt, backup }

extension FileKindX on FileKind {
  String get folder => switch (this) {
    FileKind.invoice => 'الفواتير',
    FileKind.quote => 'عروض الأسعار',
    FileKind.claim => 'خطابات المطالبة',
    FileKind.statement => 'كشوف الحساب',
    FileKind.receipt => 'سندات القبض',
    FileKind.backup => 'النسخ الاحتياطية',
  };

  /// المستندات تُرتَّب داخل مجلد السنة؛ النسخ الاحتياطية لا
  bool get byYear => this != FileKind.backup;
}

/// أين يقع المجلد الأساسي حاليًا
enum StorageLocation { root, documents, appExternal, appInternal, none }

extension StorageLocationX on StorageLocation {
  String get label => switch (this) {
    StorageLocation.root => 'الذاكرة الداخلية (الجذر)',
    StorageLocation.documents => 'مجلد Documents',
    StorageLocation.appExternal => 'مجلد التطبيق (Android/data)',
    StorageLocation.appInternal => 'ذاكرة التطبيق الخاصة',
    StorageLocation.none => 'غير متاح',
  };
}

class SavedFile {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final FileKind kind;
  const SavedFile({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.kind,
  });

  String get sizeLabel => size < 1024
      ? '$size B'
      : size < 1024 * 1024
      ? '${(size / 1024).toStringAsFixed(0)} KB'
      : '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
}

class FileService {
  static String get appFolder => Brand.current.folderName;

  static Directory? _base;
  static StorageLocation _loc = StorageLocation.none;
  static bool _resolved = false;

  /// وصف مقروء لمكان المجلد (يظهر في الإعدادات)
  static String? get basePath => _base?.path;
  static StorageLocation get location => _loc;

  /// هل الميزة متاحة على هذه المنصة؟ (غير متاحة على الويب)
  static bool get supported => !kIsWeb;

  /// يحدد المجلد الأساسي مرة واحدة ويُنشئه مع كل المجلدات الفرعية
  static Future<Directory?> base() async {
    if (!supported) return null;
    if (_resolved) return _base;
    _resolved = true;
    final r = await _resolveBase();
    _base = r?.$1;
    _loc = r?.$2 ?? StorageLocation.none;
    if (_base != null) await ensureTree();
    return _base;
  }

  /// إعادة المحاولة (مثلًا بعد منح الصلاحية). ينقل الملفات من المسار القديم إن تغيّر
  static Future<Directory?> refresh() async {
    final old = _base;
    _resolved = false;
    final now = await base();
    if (old != null && now != null && old.path != now.path) {
      await _migrate(old, now);
    }
    return now;
  }

  /// إنشاء كل مجلدات الأصناف (ومجلد السنة الحالية) فورًا
  static Future<void> ensureTree() async {
    final b = _base;
    if (b == null) return;
    final y = DateTime.now().year.toString();
    for (final k in FileKind.values) {
      try {
        await Directory(
          '${b.path}/${k.folder}${k.byYear ? '/$y' : ''}',
        ).create(recursive: true);
      } catch (e) {
        debugPrint('FileService.ensureTree ${k.folder}: $e');
      }
    }
  }

  /* ---------- صلاحية «الوصول إلى كل الملفات» (أندرويد 11+) ---------- */
  static const _ch = MethodChannel('app.storage');

  /// رقم إصدار أندرويد (API level) من الكود الأصلي — 0 إن تعذّر
  static Future<int> sdkInt() async {
    if (kIsWeb || !Platform.isAndroid) return 0;
    try {
      return await _ch.invokeMethod<int>('sdkInt') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> hasRootAccess() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final sdk = await sdkInt();
      if (sdk >= 30) return await Permission.manageExternalStorage.isGranted;
      return await Permission.storage.isGranted; // أندرويد ≤ 10
    } catch (_) {
      return false;
    }
  }

  /// يطلب الصلاحية (يفتح شاشة النظام على أندرويد 11+) ثم يعيد تحديد المجلد
  static Future<bool> requestRootAccess() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final sdk = await sdkInt();
      final r = sdk >= 30
          ? await Permission.manageExternalStorage.request()
          : await Permission.storage.request();
      if (!r.isGranted) return false;
      await refresh();
      return _loc == StorageLocation.root;
    } catch (e) {
      debugPrint('requestRootAccess: $e');
      return false;
    }
  }

  static Future<(Directory, StorageLocation)?> _resolveBase() async {
    final candidates = <(Future<Directory?> Function(), StorageLocation)>[
      (_rootDir, StorageLocation.root),
      (_publicDocuments, StorageLocation.documents),
      (_appExternal, StorageLocation.appExternal),
      (
        () async => Directory(
          '${(await getApplicationDocumentsDirectory()).path}/$appFolder',
        ),
        StorageLocation.appInternal,
      ),
    ];
    for (final (c, loc) in candidates) {
      try {
        final d = await c();
        if (d == null) continue;
        await d.create(recursive: true);
        // اختبار كتابة فعلي: بعض الإصدارات تسمح بإنشاء المجلد دون الكتابة فيه
        final probe = File('${d.path}/.probe');
        await probe.writeAsString('ok', flush: true);
        await probe.delete();
        return (d, loc);
      } catch (e) {
        debugPrint('FileService: candidate $loc failed: $e');
      }
    }
    return null;
  }

  /// /storage/emulated/0
  static Future<String?> _storageRoot() async {
    if (!Platform.isAndroid) return null;
    final ext =
        await getExternalStorageDirectory(); // .../Android/data/<pkg>/files
    if (ext == null) return null;
    final i = ext.path.indexOf('/Android/');
    return i < 0 ? null : ext.path.substring(0, i);
  }

  /// جذر الذاكرة الداخلية: /storage/emulated/0/<اسم التطبيق> — فقط عند وجود الصلاحية
  static Future<Directory?> _rootDir() async {
    if (!await hasRootAccess()) return null;
    final root = await _storageRoot();
    return root == null ? null : Directory('$root/$appFolder');
  }

  /// Documents العام: /storage/emulated/0/Documents/<اسم التطبيق> (لا يحتاج صلاحية على 11+)
  static Future<Directory?> _publicDocuments() async {
    final root = await _storageRoot();
    return root == null ? null : Directory('$root/Documents/$appFolder');
  }

  static Future<Directory?> _appExternal() async {
    if (!Platform.isAndroid) return null;
    final ext = await getExternalStorageDirectory();
    if (ext == null) return null;
    return Directory('${ext.path}/$appFolder');
  }

  /// نسخ الملفات من المسار القديم إلى الجديد (لا يستبدل الموجود، ولا يحذف الأصل)
  static Future<int> _migrate(Directory from, Directory to) async {
    var n = 0;
    try {
      if (!await from.exists()) return 0;
      await for (final e in from.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final rel = e.path.substring(from.path.length);
        final dst = File('${to.path}$rel');
        if (await dst.exists()) continue;
        await dst.parent.create(recursive: true);
        await e.copy(dst.path);
        n++;
      }
    } catch (e) {
      debugPrint('FileService._migrate: $e');
    }
    return n;
  }

  /// مسار الصور الخاصة (شعار/ختم مخصص) — داخل ذاكرة التطبيق الخاصة، لا تُحذف بحذف المجلد العام
  static Future<String?> saveBrandImage(Uint8List bytes, String name) async {
    if (!supported) return null;
    try {
      final d = Directory(
        '${(await getApplicationSupportDirectory()).path}/brand',
      );
      await d.create(recursive: true);
      final f = File('${d.path}/$name');
      await f.writeAsBytes(bytes, flush: true);
      return f.path;
    } catch (e) {
      debugPrint('saveBrandImage: $e');
      return null;
    }
  }

  static Future<Uint8List?> readBytes(String path) async {
    if (!supported || path.isEmpty) return null;
    try {
      final f = File(path);
      return await f.exists() ? await f.readAsBytes() : null;
    } catch (_) {
      return null;
    }
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
  static Future<String?> savePdf(
    Uint8List bytes,
    FileKind kind,
    String fileName, {
    String? year,
  }) async {
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

  /// يحذف النسخ الاحتياطية التلقائية الأقدم ويبقي آخر [keep] (اليدوية لا تُحذف أبدًا)
  static Future<void> pruneBackups({int keep = 30}) async {
    try {
      final all =
          (await list(
              FileKind.backup,
            )).where((f) => isAutoBackup(f.name)).toList()
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
        out.add(
          SavedFile(
            path: e.path,
            name: name,
            size: st.size,
            modified: st.modified,
            kind: kind,
          ),
        );
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

  /// نسخة تلقائية: keif-auto-… / osool-auto-… / auto-… (الإصدارات القديمة)
  static bool isAutoBackup(String name) =>
      name.startsWith('auto-') || name.contains('-auto-');

  static String safeName(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();
}
