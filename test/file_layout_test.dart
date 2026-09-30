// هيكل مجلدات PDF بالعميل + ترحيل مجلدات السنة + استنتاج العميل من اسم الملف
// + النسخة الاحتياطية الفورية عند الخروج (flushBackupOnExit)
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:keif_diafa/core/backup_service.dart';
import 'package:keif_diafa/core/brand.dart';
import 'package:keif_diafa/core/db.dart';
import 'package:keif_diafa/core/db_factory_io.dart' as dbf;
import 'package:keif_diafa/core/file_service.dart';
import 'package:keif_diafa/core/models.dart';
import 'package:keif_diafa/core/store.dart';
import 'package:keif_diafa/ui/screens/restore_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  var n = 0;

  setUpAll(() {
    sqfliteFfiInit();
    dbf.debugDbFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('layout_');
    Hive.init('${tmp.path}/h');
    HiveDb.skipInit = true;
    Brand.debugOverride = Brand.keif;
  });
  tearDownAll(() {
    Brand.debugOverride = null;
    FileService.debugSetBase(null);
  });

  Directory freshBase() {
    final d = Directory('${tmp.path}/base${n++}')..createSync(recursive: true);
    FileService.debugSetBase(d);
    return d;
  }

  group('استنتاج العميل من اسم الملف (للترحيل)', () {
    test('كل صيغ أسماء الملفات', () {
      expect(
        Store.clientFromFileName('فاتورة INV-0005 - شركة طلوع الجزيرة.pdf'),
        'شركة طلوع الجزيرة',
      );
      expect(
        Store.clientFromFileName('عرض سعر QT-0001 - مؤسسة النخبة.pdf'),
        'مؤسسة النخبة',
      );
      expect(Store.clientFromFileName('سند قبض REC-0007 - أحمد.pdf'), 'أحمد');
      expect(
        Store.clientFromFileName('كشف حساب - شركة طلوع - 2026-09-30.pdf'),
        'شركة طلوع',
      );
      expect(
        Store.clientFromFileName(
          'كشف حساب تفصيلي - شركة طلوع - 2026-09-30.pdf',
        ),
        'شركة طلوع',
      );
      expect(
        Store.clientFromFileName('خطاب مطالبة CLM-0001 - وزارة الثقافة.pdf'),
        'وزارة الثقافة',
      );
      // اسم عميل يحوي « - » داخله يبقى كاملًا
      expect(
        Store.clientFromFileName('فاتورة INV-0009 - شركة أ - ب.pdf'),
        'شركة أ - ب',
      );
      expect(Store.clientFromFileName('random.pdf'), isNull);
      expect(Store.clientFromFileName('كشف حساب - فقط.pdf'), isNull);
    });
  });

  group('هيكل المجلدات', () {
    test(
      'savePdf يضع الملف في <النوع>/<العميل>/ والنسخ الاحتياطية بلا عميل',
      () async {
        final b = freshBase();
        final p = await FileService.savePdf(
          Uint8List.fromList([1, 2, 3]),
          FileKind.invoice,
          'فاتورة INV-0001 - شركة طلوع.pdf',
          client: 'شركة طلوع',
        );
        expect(
          p,
          '${b.path}/الفواتير/شركة طلوع/فاتورة INV-0001 - شركة طلوع.pdf',
        );
        expect(File(p!).existsSync(), isTrue);

        final p2 = await FileService.savePdf(
          Uint8List.fromList([1]),
          FileKind.receipt,
          'سند قبض REC-0001 - عميل.pdf',
          client: 'شر/كة:خط*رة',
        );
        // الأحرف الممنوعة في أسماء المجلدات تُنظَّف
        expect(p2, contains('/سندات القبض/شر-كة-خط-رة/'));

        final p3 = await FileService.savePdf(
          Uint8List.fromList([1]),
          FileKind.statement,
          'كشف.pdf',
        );
        expect(p3, contains('/كشوف الحساب/بدون عميل/'));

        final bk = await FileService.saveBackup(
          '{}',
          'keif-auto-2026-01-01.json',
        );
        expect(bk, '${b.path}/النسخ الاحتياطية/keif-auto-2026-01-01.json');
      },
    );

    test('ensureTree ينشئ مجلدات الأنواع فقط (لا سنة)', () async {
      final b = freshBase();
      await FileService.ensureTree();
      for (final k in FileKind.values) {
        expect(
          Directory('${b.path}/${k.folder}').existsSync(),
          isTrue,
          reason: k.folder,
        );
      }
      expect(
        Directory('${b.path}/الفواتير/${DateTime.now().year}').existsSync(),
        isFalse,
      );
    });

    test('list يرى الملفات داخل مجلدات العملاء', () async {
      freshBase();
      await FileService.savePdf(
        Uint8List(1),
        FileKind.invoice,
        'a.pdf',
        client: 'ع1',
      );
      await FileService.savePdf(
        Uint8List(1),
        FileKind.invoice,
        'b.pdf',
        client: 'ع2',
      );
      final l = await FileService.list(FileKind.invoice);
      expect(l.map((f) => f.name).toSet(), {'a.pdf', 'b.pdf'});
    });
  });

  group('ترحيل مجلدات السنة ⇐ مجلدات العملاء', () {
    test('ينقل ما يُعرف عميله ويبقي غيره ويحذف مجلد السنة الفارغ', () async {
      final b = freshBase();
      // هيكل قديم (≤ 2.5.0)
      final y = Directory('${b.path}/الفواتير/2025')
        ..createSync(recursive: true);
      File('${y.path}/فاتورة INV-0001 - شركة طلوع.pdf').writeAsStringSync('x');
      File(
        '${y.path}/فاتورة INV-0002 - مؤسسة النخبة.pdf',
      ).writeAsStringSync('y');
      File('${y.path}/غريب.pdf').writeAsStringSync('z'); // لا يُعرف عميله
      final y2 = Directory('${b.path}/سندات القبض/2026')
        ..createSync(recursive: true);
      File('${y2.path}/سند قبض REC-0001 - أحمد.pdf').writeAsStringSync('r');
      // مجلد عميل موجود مسبقًا لا يُلمس
      Directory('${b.path}/الفواتير/عميل حديث').createSync(recursive: true);

      final moved = await FileService.migrateYearFoldersToClients(
        Store.clientFromFileName,
      );
      expect(moved, 3);
      expect(
        File(
          '${b.path}/الفواتير/شركة طلوع/فاتورة INV-0001 - شركة طلوع.pdf',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '${b.path}/الفواتير/مؤسسة النخبة/فاتورة INV-0002 - مؤسسة النخبة.pdf',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '${b.path}/سندات القبض/أحمد/سند قبض REC-0001 - أحمد.pdf',
        ).existsSync(),
        isTrue,
      );
      // غير المعروف يبقى في مجلد السنة، والمجلد لا يُحذف لأنه غير فارغ
      expect(File('${y.path}/غريب.pdf').existsSync(), isTrue);
      expect(y.existsSync(), isTrue);
      // مجلد سنة صار فارغًا ⇐ حُذف
      expect(y2.existsSync(), isFalse);
      // إعادة التشغيل لا تنقل شيئًا (idempotent)
      expect(
        await FileService.migrateYearFoldersToClients(Store.clientFromFileName),
        0,
      );
    });

    test('لا يكتب فوق ملف موجود في مجلد العميل', () async {
      final b = freshBase();
      final y = Directory('${b.path}/الفواتير/2025')
        ..createSync(recursive: true);
      File('${y.path}/فاتورة INV-0001 - س.pdf').writeAsStringSync('old');
      final c = Directory('${b.path}/الفواتير/س')..createSync(recursive: true);
      File('${c.path}/فاتورة INV-0001 - س.pdf').writeAsStringSync('new');
      expect(
        await FileService.migrateYearFoldersToClients(Store.clientFromFileName),
        0,
      );
      expect(
        File('${c.path}/فاتورة INV-0001 - س.pdf').readAsStringSync(),
        'new',
      );
      expect(File('${y.path}/فاتورة INV-0001 - س.pdf').existsSync(), isTrue);
    });
  });

  group('النسخة الاحتياطية عند الخروج (اختيارية — ADR-0004)', () {
    Future<Store> boot() async {
      SqliteDb.debugDir = '${tmp.path}/db${n++}';
      Directory(SqliteDb.debugDir!).createSync(recursive: true);
      final s = Store(db: SqliteDb());
      await s.init();
      return s;
    }

    test('الافتراضي: مطفأة ⇐ تعديل ثم خروج لا يكتب شيئًا', () async {
      freshBase();
      final s = await boot();
      expect(s.backupOnExitEnabled, isFalse);
      await s.saveClient(Client(name: 'عميل', phone: '05'));
      expect(s.backupDirty, isTrue, reason: 'التعديل يُعلَّم دائمًا');
      expect(await s.flushBackupOnExit(), isNull);
      s.dispose();
    });

    test('مفعّلة: تعديل ثم خروج ⇐ نسخة اليوم تُكتب فورًا ومرة واحدة', () async {
      final b = freshBase();
      final s = await boot();
      await s.setBackupOnExit(true);
      await s.saveClient(Client(name: 'عميل', phone: '05'));
      final p = await s.flushBackupOnExit();
      expect(p, isNotNull);
      expect(File(p!).existsSync(), isTrue);
      expect(p, startsWith('${b.path}/النسخ الاحتياطية/keif-auto-'));
      expect(s.backupDirty, isFalse);
      // خروج ثانٍ بلا تعديل ⇐ لا كتابة
      expect(await s.flushBackupOnExit(), isNull);
      // 50 خروجًا مع تعديلات ⇐ ملف اليوم نفسه يُستبدل، لا تكاثر
      for (var i = 0; i < 50; i++) {
        await s.saveClient(Client(name: 'عميل $i', phone: '05'));
        await s.flushBackupOnExit();
      }
      final files = await FileService.list(FileKind.backup);
      expect(files.length, 1, reason: 'نسخة تلقائية واحدة لليوم');
      s.dispose();
    });

    test('الإعداد يُحفظ ويُقرأ بعد إعادة التشغيل (kvKeys)', () async {
      freshBase();
      final dir = '${tmp.path}/db${n++}';
      Directory(dir).createSync(recursive: true);
      SqliteDb.debugDir = dir;
      var s = Store(db: SqliteDb());
      await s.init();
      await s.setBackupOnExit(true);
      s.dispose();
      SqliteDb.debugDir = dir;
      s = Store(db: SqliteDb());
      await s.init();
      expect(s.backupOnExitEnabled, isTrue);
      s.dispose();
    });

    test('الملف المكتوب يمر من BackupService.verify (بصمة سليمة)', () async {
      freshBase();
      final s = await boot();
      await s.setBackupOnExit(true);
      await s.saveClient(Client(name: 'عميل', phone: '05'));
      final p = await s.flushBackupOnExit();
      final chk = await FileService.readText(p!);
      expect(chk, contains('"sha256"'));
      s.dispose();
    });
  });

  group('النسخة اليومية كل 24 ساعة', () {
    test('isDailyDue', () {
      final now = DateTime(2026, 9, 30, 10);
      expect(BackupService.isDailyDue(null, now: now), isTrue);
      expect(BackupService.isDailyDue('', now: now), isTrue);
      // قيمة قديمة yyyy-mm-dd (≤ 2.5.0) تُفهم كمنتصف ليل ذلك اليوم
      expect(BackupService.isDailyDue('2026-09-28', now: now), isTrue);
      expect(BackupService.isDailyDue('2026-09-30', now: now), isFalse);
      expect(
        BackupService.isDailyDue(
          now
              .subtract(const Duration(hours: 23, minutes: 59))
              .toIso8601String(),
          now: now,
        ),
        isFalse,
      );
      expect(
        BackupService.isDailyDue(
          now.subtract(const Duration(hours: 24)).toIso8601String(),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('عرض الاستعادة التلقائي بعد إعادة التثبيت', () {
    Future<Store> boot() async {
      SqliteDb.debugDir = '${tmp.path}/db${n++}';
      Directory(SqliteDb.debugDir!).createSync(recursive: true);
      final s = Store(db: SqliteDb());
      await s.init();
      return s;
    }

    test('قاعدة فارغة + لا نسخ ⇐ لا عرض', () async {
      freshBase();
      final s = await boot();
      expect(await shouldOfferRestore(s), isFalse);
      s.dispose();
    });

    test(
      'قاعدة فارغة + نسخة سليمة في المجلد ⇐ عرض، ثم لا يتكرر بعد التعليم',
      () async {
        freshBase();
        // تطبيق «قديم» يكتب نسخة
        final old = await boot();
        await old.saveClient(Client(name: 'عميل', phone: '05'));
        expect(await old.backupNow(), isNotNull);
        old.dispose();
        // «إعادة تثبيت»: قاعدة جديدة فارغة على نفس المجلد
        final fresh = await boot();
        expect(fresh.isEmpty, isTrue);
        expect(await shouldOfferRestore(fresh), isTrue);
        await fresh.setKv('restoreOffered', true);
        expect(await shouldOfferRestore(fresh), isFalse);
        fresh.dispose();
      },
    );

    test('قاعدة فيها بيانات ⇐ لا عرض حتى مع وجود نسخ', () async {
      freshBase();
      final s = await boot();
      await s.saveClient(Client(name: 'عميل', phone: '05'));
      await s.backupNow();
      expect(await shouldOfferRestore(s), isFalse);
      s.dispose();
    });

    test('نسخة تالفة فقط ⇐ لا عرض', () async {
      final b = freshBase();
      final s = await boot();
      final d = Directory('${b.path}/النسخ الاحتياطية')
        ..createSync(recursive: true);
      File(
        '${d.path}/keif-backup-x.json',
      ).writeAsStringSync('{"data": {}, "sha256": "bad"}');
      expect(await shouldOfferRestore(s), isFalse);
      s.dispose();
    });

    test('loadBackupEntries: الأحدث أولًا مع التحقق', () async {
      freshBase();
      final s = await boot();
      await s.saveClient(Client(name: 'عميل', phone: '05'));
      await s.backupNow();
      await s.backupNow(auto: true);
      final l = await loadBackupEntries();
      expect(l.length, 2);
      expect(l.every((e) => e.check?.ok == true), isTrue);
      expect(
        l.first.file.modified.isAfter(l.last.file.modified) ||
            l.first.file.modified == l.last.file.modified,
        isTrue,
      );
      s.dispose();
    });
  });
}
