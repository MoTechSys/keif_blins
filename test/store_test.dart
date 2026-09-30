import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:keif_diafa/core/backup_service.dart';
import 'package:keif_diafa/core/brand.dart';
import 'package:keif_diafa/core/db.dart';
import 'package:keif_diafa/core/db_factory_io.dart' as dbf;
import 'package:keif_diafa/core/models.dart';
import 'package:keif_diafa/core/store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// اختبارات المخزن على **SQLite حقيقي** (محرك سطح المكتب ffi) — نفس الكود الذي يعمل على أندرويد
void main() {
  late Directory tmp;
  var n = 0;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    dbf.debugDbFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('keif_store_');
    Hive.init('${tmp.path}/hive');
    HiveDb.skipInit = true;
  });
  tearDownAll(() async {
    await Hive.close();
    tmp.deleteSync(recursive: true);
  });

  /// مخزن جديد بقاعدة مستقلة في مجلد مؤقت
  Future<Store> fresh() async {
    SqliteDb.debugDir = '${tmp.path}/db${n++}';
    Directory(SqliteDb.debugDir!).createSync(recursive: true);
    final s = Store(db: SqliteDb());
    await s.init();
    expect(s.initError, isNull);
    expect(s.ready, isTrue);
    return s;
  }

  test('import tolerates corrupt records and keeps valid ones', () async {
    final s = await fresh();
    final json = jsonEncode({
      'app': 'keif-diafa',
      'schema': 2,
      'data': {
        'clients': [
          Client(name: 'عميل صالح').toMap(),
          'not-a-map',
          {'id': 'bad', 'openingBalance': 'xyz'},
        ],
        'docs': [Invoice(clientId: 'c1', number: 'INV-0007').toMap(), 42],
        'payments': [null],
        'org': {'name': 'مؤسسة الاختبار'},
      },
    });
    final n = await s.importJson(json);
    expect(n, greaterThanOrEqualTo(2));
    expect(s.clients.any((c) => c.name == 'عميل صالح'), isTrue);
    expect(s.docs.any((d) => d.number == 'INV-0007'), isTrue);
    expect(s.org.name, 'مؤسسة الاختبار');
    // نسخة قديمة بلا numberingMode ⇐ تبقى تسلسلية (ADR-0003)
    expect(s.org.numberingMode, 'seq');
    s.docs.add(Invoice(clientId: 'c1', number: 'INV-99999999999999999999999'));
    expect(() => s.nextNumber(DocKind.invoice), returnsNormally);
    expect(s.nextNumber(DocKind.invoice), endsWith('0008'));
    await s.wipe();
    expect(s.clients, isEmpty);
    expect(s.org.name, isNot('مؤسسة الاختبار'));
  });

  test('invalid backup rejected', () async {
    final s = await fresh();
    expect(() => s.importJson('{"x":1}'), throwsA(isA<FormatException>()));
  });

  test(
    'SQLite persists across reopen (WAL, transactions) + integrity check',
    () async {
      final s = await fresh();
      final dir = SqliteDb.debugDir;
      final c = Client(name: 'فندق المنتزه');
      await s.saveClient(c);
      final inv = Invoice(
        clientId: c.id,
        status: 'issued',
        items: [LineItem(desc: 'ضيافة', unitPrice: 100000)],
      );
      await s.saveDoc(inv);
      await s.savePayment(
        Payment(clientId: c.id, invoiceId: inv.id, amount: 40000),
      );
      await s.saveClaim(
        Claim(
          clientId: c.id,
          recipient: c.name,
          items: [ClaimItem(desc: 'بند', amount: 60000)],
        ),
      );
      expect(s.database.engine, contains('SQLite'));
      expect(await s.database.integrityCheck(), isNull);
      await s.database.close();

      // إعادة فتح نفس الملف: كل شيء موجود
      SqliteDb.debugDir = dir;
      final s2 = Store(db: SqliteDb());
      await s2.init();
      expect(s2.clients.single.name, 'فندق المنتزه');
      expect(s2.invoices.single.invoiceStatus, InvoiceStatus.partial);
      expect(s2.payments.single.amount, 40000);
      expect(s2.claims.single.total, 60000);
      expect(s2.claims.single.number, startsWith('CLM-'));

      // حذف العميل ينقل مستنداته ومطالباته إلى السلة معًا، والاسترجاع يعيدها معًا
      await s2.deleteClient(c.id);
      expect(s2.clients, isEmpty);
      expect(s2.claims, isEmpty);
      expect(s2.trashClaims, hasLength(1));
      await s2.restoreClient(c.id);
      expect(s2.claims, hasLength(1));
      expect(s2.docs, hasLength(1));
      await s2.database.close();
    },
  );

  test('one-time migration from legacy Hive box keeps every record', () async {
    // صندوق Hive قديم بنفس اسم قاعدة النسخة (كما في الإصدار 2.2.0)
    final legacy = await Hive.openBox(Brand.current.dbName);
    await legacy.putAll({
      'clients': [Client(id: 'c_old', name: 'عميل قديم').toMap()],
      'docs': [
        Invoice(
          id: 'i_old',
          clientId: 'c_old',
          number: 'INV-0042',
          status: 'issued',
        ).toMap(),
      ],
      'payments': [
        Payment(
          id: 'p_old',
          clientId: 'c_old',
          invoiceId: 'i_old',
          amount: 500,
        ).toMap(),
      ],
      'org': Org(name: 'مؤسسة قديمة').toMap(),
      'signedIn': true,
      'autoBackup': false,
    });
    await legacy.close();

    final s = await fresh();
    expect(s.migratedFromHive, 3);
    expect(s.clients.single.name, 'عميل قديم');
    expect(s.docs.single.number, 'INV-0042');
    expect(s.payments.single.amount, 500);
    expect(s.org.name, 'مؤسسة قديمة');
    expect(s.signedIn, isTrue);
    expect(s.autoBackupEnabled, isFalse);
    // الصندوق القديم يبقى (نسخة أمان) ولا يُعاد ترحيله
    expect(await Hive.boxExists(Brand.current.dbName), isTrue);
    final dir = SqliteDb.debugDir;
    await s.database.close();
    SqliteDb.debugDir = dir;
    final again = Store(db: SqliteDb());
    await again.init();
    expect(again.migratedFromHive, 0);
    expect(again.clients, hasLength(1));
    await again.database.close();
    await Hive.deleteBoxFromDisk(Brand.current.dbName);
  });

  test(
    'backup: SHA-256 verified, tamper detected, other brand rejected',
    () async {
      final s = await fresh();
      await s.saveClient(Client(name: 'شركة جانسون'));
      await s.saveClaim(
        Claim(
          recipient: 'جهة',
          items: [ClaimItem(desc: 'x', amount: 1)],
        ),
      );
      final text = BackupService.encode(s);
      final ok = BackupService.verify(text);
      expect(ok.ok, isTrue);
      expect(ok.hasHash, isTrue);
      expect(ok.counts['clients'], 1);
      expect(ok.counts['claims'], 1);

      // تعديل حرف واحد في البيانات ← يُكتشف
      final tampered = text.replaceFirst('شركة جانسون', 'شركة جانسن');
      final bad = BackupService.verify(tampered);
      expect(bad.ok, isFalse);
      expect(bad.message, contains('بصمة'));

      // نسخة تخص «أصول الضيافة» لا تُسترجع في «كيف الضيافة»
      final m = jsonDecode(text) as Map;
      m['brand'] = 'osool';
      final other = BackupService.verify(jsonEncode(m));
      expect(other.ok, isFalse);
      expect(other.message, contains('أصول الضيافة'));

      // نسخ الإصدارات القديمة (بلا بصمة) تُقبل
      final old = BackupService.verify(
        jsonEncode({
          'app': 'keif-diafa',
          'data': {'clients': []},
        }),
      );
      expect(old.ok, isTrue);
      expect(old.hasHash, isFalse);

      // الاسترجاع الكامل ذهابًا وإيابًا
      final s2 = await fresh();
      await s2.importJson(text);
      expect(s2.clients.single.name, 'شركة جانسون');
      expect(s2.claims.single.recipient, 'جهة');
    },
  );

  test('claim from invoices uses remaining amounts and invoice refs', () async {
    final s = await fresh();
    final c = Client(name: 'مستشفى');
    await s.saveClient(c);
    final a = Invoice(
      clientId: c.id,
      status: 'issued',
      location: 'جدة',
      eventDate: '2026-09-21',
      items: [LineItem(desc: 'ضيافة قهوة\nتفاصيل', unitPrice: 480000)],
    );
    final b = Invoice(
      clientId: c.id,
      status: 'issued',
      items: [LineItem(desc: 'ضيافة', unitPrice: 150000)],
    );
    await s.saveDoc(a);
    await s.saveDoc(b);
    await s.savePayment(
      Payment(clientId: c.id, invoiceId: a.id, amount: 80000),
    );
    final cl = s.claimFromInvoices(c, [a, b]);
    expect(cl.items, hasLength(2));
    expect(cl.items.first.amount, 400000);
    expect(cl.items.first.desc, contains('ضيافة قهوة'));
    expect(cl.items.first.desc, isNot(contains('تفاصيل')));
    expect(cl.items.first.invoiceNumber, a.number);
    expect(cl.total, 550000);
    expect(cl.recipient, 'مستشفى');
  });

  test(
    'كل مفتاح يُكتب بـ setKv مسجّل في Store.kvKeys (وإلا لا يُقرأ بعد إعادة التشغيل)',
    () {
      // نجمع كل setKv('x' / kv('x') في lib/ ونتحقق أن x في السجل
      final used = <String>{};
      final re = RegExp(r"""(?:setKv|kv)\(\s*'([A-Za-z_]+)'""");
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        for (final m in re.allMatches(f.readAsStringSync())) {
          used.add(m[1]!);
        }
      }
      expect(used, isNotEmpty);
      final missing = used.where((k) => !Store.kvKeys.contains(k)).toList();
      expect(
        missing,
        isEmpty,
        reason: 'أضف المفاتيح إلى Store.kvKeys: $missing',
      );
    },
  );
}
