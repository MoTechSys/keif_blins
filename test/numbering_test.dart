// الترقيم (ADR-0003): الافتراضي «التاريخ والوقت» لكل المستندات، والتسلسلي اختياري
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:keif_diafa/core/brand.dart';
import 'package:keif_diafa/core/db.dart';
import 'package:keif_diafa/core/db_factory_io.dart' as dbf;
import 'package:keif_diafa/core/models.dart';
import 'package:keif_diafa/core/store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  var n = 0;

  setUpAll(() {
    sqfliteFfiInit();
    dbf.debugDbFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('num_');
    Hive.init('${tmp.path}/h');
    HiveDb.skipInit = true;
    Brand.debugOverride = Brand.keif;
  });
  tearDownAll(() => Brand.debugOverride = null);

  Future<Store> boot() async {
    SqliteDb.debugDir = '${tmp.path}/db${n++}';
    Directory(SqliteDb.debugDir!).createSync(recursive: true);
    final s = Store(db: SqliteDb());
    await s.init();
    return s;
  }

  final dt = RegExp(r'^[A-Z]+-\d{8}-\d{6}(-\d+)?$');

  group('الافتراضي', () {
    test('تثبيت جديد ⇐ datetime', () {
      expect(Org().numberingMode, 'datetime');
      expect(Org.fromMap(null).numberingMode, 'datetime');
      expect(Org.fromMap({}).numberingMode, 'datetime');
    });
    test(
      'إعدادات قديمة محفوظة بلا المفتاح ⇐ تبقى seq (لا مفاجأة للمستخدم)',
      () {
        expect(Org.fromMap({'name': 'مؤسسة'}).numberingMode, 'seq');
        expect(
          Org.fromMap({'name': 'م', 'numberingMode': 'seq'}).numberingMode,
          'seq',
        );
        expect(
          Org.fromMap({'name': 'م', 'numberingMode': 'datetime'}).numberingMode,
          'datetime',
        );
      },
    );
  });

  group('نمط التاريخ والوقت', () {
    test('فاتورة/عرض/مطالبة/سند بنفس النمط', () async {
      final s = await boot();
      expect(s.nextNumber(DocKind.invoice), matches(dt));
      expect(s.nextNumber(DocKind.invoice), startsWith('INV-'));
      expect(s.nextNumber(DocKind.quotation), startsWith('QT-'));
      expect(s.nextClaimNumber(), startsWith('CLM-'));
      expect(s.nextClaimNumber(), matches(dt));
      expect(s.nextReceiptNumber(), startsWith('REC-'));
      expect(s.nextReceiptNumber(), matches(dt));
      s.dispose();
    });

    test('تكرار في نفس الثانية ⇐ لاحقة -1 -2 …', () {
      final taken = <String>{};
      final at = DateTime(2026, 9, 30, 14, 35, 22);
      final a = Store.datetimeNumber('INV-', taken.contains, at: at);
      expect(a, 'INV-20260930-143522');
      taken.add(a);
      final b = Store.datetimeNumber('INV-', taken.contains, at: at);
      expect(b, 'INV-20260930-143522-1');
      taken.add(b);
      expect(
        Store.datetimeNumber('INV-', taken.contains, at: at),
        'INV-20260930-143522-2',
      );
    });

    test('سندات قبض متتالية في نفس الثانية فريدة', () async {
      final s = await boot();
      final c = Client(name: 'ع', phone: '05');
      await s.saveClient(c);
      final nums = <String>{};
      for (var i = 0; i < 5; i++) {
        final p = Payment(clientId: c.id, amount: 100);
        await s.savePayment(p);
        nums.add(p.receiptNumber);
      }
      expect(nums.length, 5);
      s.dispose();
    });
  });

  group('التبديل بين النمطين', () {
    test('seq بعد datetime لا يقفز إلى الملايين', () async {
      final s = await boot();
      final c = Client(name: 'ع', phone: '05');
      await s.saveClient(c);
      final d1 = Invoice(clientId: c.id, number: s.nextNumber(DocKind.invoice));
      await s.saveDoc(d1);
      final p1 = Payment(clientId: c.id, amount: 1);
      await s.savePayment(p1);
      final cl = Claim(clientId: c.id, number: s.nextClaimNumber());
      await s.saveClaim(cl);
      expect(d1.number, matches(dt));
      await s.saveOrg(s.org..numberingMode = 'seq');
      expect(s.nextNumber(DocKind.invoice), 'INV-0001');
      expect(s.nextReceiptNumber(), 'REC-0001');
      expect(s.nextClaimNumber(), 'CLM-0001');
      // ثم ترقيم تسلسلي عادي
      await s.saveDoc(Invoice(clientId: c.id, number: 'INV-0001'));
      expect(s.nextNumber(DocKind.invoice), 'INV-0002');
      await s.savePayment(Payment(clientId: c.id, amount: 1));
      expect(s.nextReceiptNumber(), 'REC-0002');
      s.dispose();
    });
  });
}
