/// drive_service.dart — النسخ الاحتياطي السحابي إلى Google Drive | نظام الفواتير
///
/// - تُحفظ النسخ في **مجلد التطبيق المخفي** في Drive (appDataFolder): لا تظهر في ملفات المستخدم
///   ولا يستطيع أي تطبيق آخر قراءتها، ويحذفها Google تلقائيًا فقط إن ألغى المستخدم صلاحية التطبيق.
/// - كل نسخة نفس ملف الجهاز المُتحقَّق منه (SHA-256)، ويُقارَن md5 الذي يحسبه Google بعد الرفع
///   مع md5 المحلي — إن اختلفا تُعتبر النسخة فاشلة.
/// - الاسم يحمل معرّف النسخة (keif / osool) فلا تختلط نسخ المؤسستين حتى على نفس الحساب.
/// - الرفع التلقائي مرة يوميًا (عند التفعيل)، ويُحتفظ بآخر [keep] نسخة.
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'backup_service.dart';
import 'brand.dart';
import 'models.dart';
import 'store.dart';

class DriveBackup {
  final String id, name;
  final DateTime? modified;
  final int size;
  const DriveBackup(this.id, this.name, this.modified, this.size);
}

class DriveService {
  static const keep = 30;
  static final _signIn = GoogleSignIn(
    scopes: const ['email', drive.DriveApi.driveAppdataScope],
  );

  /// الحساب الحالي (إن سجّل المستخدم الدخول)
  static GoogleSignInAccount? get account => _signIn.currentUser;

  static String get _prefix => '${Brand.current.backupPrefix}-drive-';

  /// دخول صامت (بلا نافذة) — يُستخدم للرفع التلقائي
  static Future<GoogleSignInAccount?> silent() async {
    try {
      return _signIn.currentUser ?? await _signIn.signInSilently();
    } catch (e) {
      debugPrint('Drive.silent: $e');
      return null;
    }
  }

  /// دخول تفاعلي مع طلب صلاحية Drive (مرة واحدة)
  static Future<GoogleSignInAccount?> signIn() async {
    final acc = await _signIn.signIn();
    if (acc == null) return null;
    final ok = await _signIn.requestScopes(const [
      drive.DriveApi.driveAppdataScope,
    ]);
    if (!ok) throw Exception('لم تُمنح صلاحية حفظ النسخ في Google Drive');
    return acc;
  }

  static Future<void> signOut() async {
    try {
      await _signIn.disconnect();
    } catch (_) {
      await _signIn.signOut();
    }
  }

  static Future<drive.DriveApi> _api({bool interactive = false}) async {
    var acc = await silent();
    if (acc == null && interactive) acc = await signIn();
    if (acc == null) throw Exception('سجّل الدخول بحساب Google أولًا');
    final client = await _signIn.authenticatedClient();
    if (client == null) {
      throw Exception('تعذّر الحصول على تصريح Google — أعد تسجيل الدخول');
    }
    return drive.DriveApi(client);
  }

  /// رفع نسخة الآن. يعيد اسم الملف المرفوع
  static Future<String> upload(Store s, {bool interactive = true}) async {
    final api = await _api(interactive: interactive);
    final text = BackupService.encode(s);
    final bytes = utf8.encode(text);
    final localMd5 = md5.convert(bytes).toString();
    final name = '$_prefix${Store.backupStamp()}.json';
    final meta = drive.File()
      ..name = name
      ..parents = ['appDataFolder']
      ..mimeType = 'application/json';
    final created = await api.files.create(
      meta,
      uploadMedia: drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: 'application/json',
      ),
      $fields: 'id,name,md5Checksum,size',
    );
    if (created.md5Checksum != null && created.md5Checksum != localMd5) {
      if (created.id != null) await api.files.delete(created.id!);
      throw Exception(
        'فشل التحقق بعد الرفع (md5 غير متطابق) — أُلغيت النسخة، أعد المحاولة',
      );
    }
    await s.setKv('lastDriveBackup', DateTime.now().toIso8601String());
    unawaited(_prune(api));
    return name;
  }

  static Future<List<DriveBackup>> list() async {
    final api = await _api();
    final r = await api.files.list(
      spaces: 'appDataFolder',
      q: "name contains '$_prefix' and trashed = false",
      orderBy: 'modifiedTime desc',
      pageSize: 100,
      $fields: 'files(id,name,modifiedTime,size)',
    );
    return [
      for (final f in r.files ?? const <drive.File>[])
        if (f.id != null && (f.name ?? '').startsWith(_prefix))
          DriveBackup(
            f.id!,
            f.name!,
            f.modifiedTime,
            int.tryParse(f.size ?? '') ?? 0,
          ),
    ];
  }

  static Future<String> download(String id) async {
    final api = await _api();
    final media =
        await api.files.get(
              id,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    final chunks = <int>[];
    await for (final c in media.stream) {
      chunks.addAll(c);
    }
    return utf8.decode(chunks);
  }

  static Future<void> _prune(drive.DriveApi api) async {
    try {
      final r = await api.files.list(
        spaces: 'appDataFolder',
        q: "name contains '$_prefix' and trashed = false",
        orderBy: 'modifiedTime desc',
        pageSize: 200,
        $fields: 'files(id,name)',
      );
      final files = r.files ?? const <drive.File>[];
      for (final f in files.skip(keep)) {
        if (f.id != null) await api.files.delete(f.id!);
      }
    } catch (e) {
      debugPrint('Drive.prune: $e');
    }
  }

  /// الرفع اليومي التلقائي (صامت، لا يُظهر نوافذ). يُتجاهل بهدوء إن لم يُسجَّل الدخول/لا إنترنت
  static Future<void> dailyIfDue(Store s) async {
    if (kIsWeb || s.kv('driveAuto') != true) return;
    final last = DateTime.tryParse('${s.kv('lastDriveBackup') ?? ''}');
    if (last != null && todayISO() == _iso(last)) return;
    try {
      await upload(s, interactive: false);
    } catch (e) {
      debugPrint('Drive.dailyIfDue: $e');
    }
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
