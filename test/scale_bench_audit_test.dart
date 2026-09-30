// قياس قابلية التوسّع (ليست اختبارًا دائمًا — يُشغَّل يدويًا):
//   flutter test test/scale_bench_audit_test.dart
// يقيس على SQLite حقيقي (FFI):
//   - زمن الحفظ الواحد (saveDoc) عند 100 / 1,000 / 3,000 فاتورة — لأن replaceTables
//     يعيد كتابة الجدول كاملًا في كل حفظ (O(n) لكل عملية).
//   - زمن فتح التطبيق (Store.init) عند نفس الأحجام.
//   - زمن بناء كشف حساب لعميل واحد بـ 1,000 فاتورة.
//   - زمن توليد PDF لفاتورة عادية (على الخيط الرئيسي).
// النتائج تُطبع وتُكتب في build/ux/scale.json لتلخيصها في docs/AUDIT_*.md
@Tags(['audit'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:keif_diafa/core/brand.dart';
import 'package:keif_diafa/core/db.dart';
import 'package:keif_diafa/core/db_factory_io.dart' as dbf;
import 'package:keif_diafa/core/models.dart';
import 'package:keif_diafa/core/store.dart';
import 'package:keif_diafa/pdf/documents.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  final results = <String, dynamic>{};

  setUpAll(() async {
    sqfliteFfiInit();
    dbf.debugDbFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('scale_');
    Hive.init('${tmp.path}/h');
    HiveDb.skipInit = true;
    Brand.debugOverride = Brand.keif;
  });
  tearDownAll(() {
    Brand.debugOverride = null;
    final f = File('build/ux/scale.json');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(results));
  });

  Future<Store> fresh(String name) async {
    SqliteDb.debugDir = '${tmp.path}/$name';
    Directory(SqliteDb.debugDir!).createSync(recursive: true);
    final s = Store(db: SqliteDb());
    await s.init();
    return s;
  }

  Invoice mk(Client c, int i) => Invoice(
    clientId: c.id,
    clientName: c.name,
    eventDate: '2026-0${1 + i % 9}-1${i % 9}',
    location: 'جدة — قاعة رقم $i',
    items: [
      LineItem(desc: 'ضيافة كاملة للمناسبة رقم $i', unitPrice: 250000 + i),
      LineItem(desc: 'صانع قهوة', unitPrice: 150000, qty: 2, unitLabel: 'ساعة'),
    ],
  );

  for (final n in [100, 1000, 3000]) {
    test('scale n=$n', () async {
      final s = await fresh('n$n');
      final c = Client(name: 'عميل الاختبار', phone: '0500000000');
      await s.saveClient(c);
      // تعبئة أولية عبر الواجهة العامة (كل saveDoc يعيد كتابة الجدول)
      final fill = Stopwatch()..start();
      for (var i = 0; i < n; i++) {
        final inv = mk(c, i);
        inv.number = s.nextNumber(DocKind.invoice);
        await s.saveDoc(inv);
      }
      fill.stop();
      // زمن حفظ واحد عند هذا الحجم (متوسط 5)
      final one = Stopwatch()..start();
      for (var k = 0; k < 5; k++) {
        final inv = mk(c, n + k);
        inv.number = s.nextNumber(DocKind.invoice);
        await s.saveDoc(inv);
      }
      one.stop();
      // دفعة واحدة (تعيد كتابة payments + docs لتحديث الحالة)
      final pay = Stopwatch()..start();
      await s.savePayment(
        Payment(clientId: c.id, invoiceId: s.docs.last.id, amount: 1000),
      );
      pay.stop();
      // زمن فتح التطبيق بقاعدة بهذا الحجم
      s.dispose();
      final open = Stopwatch()..start();
      final s2 = Store(db: SqliteDb());
      await s2.init();
      open.stop();
      // كشف حساب لعميل واحد بكل الفواتير
      final st = Stopwatch()..start();
      final stmt = buildStatement(
        client: c,
        invoices: s2.docs,
        payments: s2.payments,
      );
      st.stop();
      final dbFile = File('${SqliteDb.debugDir}/${Brand.current.dbName}.db');
      final dbKb = dbFile.existsSync() ? dbFile.lengthSync() ~/ 1024 : -1;
      results['n$n'] = {
        'fill_total_ms': fill.elapsedMilliseconds,
        'save_one_ms': one.elapsedMilliseconds / 5,
        'save_payment_ms': pay.elapsedMilliseconds,
        'store_init_ms': open.elapsedMilliseconds,
        'statement_ms': st.elapsedMilliseconds,
        'statement_rows': stmt.rows.length,
        'db_kb': dbKb,
        'docs': s2.docs.length,
      };
      // ignore: avoid_print
      print('n=$n ${results['n$n']}');
      s2.dispose();
    }, timeout: const Timeout(Duration(minutes: 10)));
  }

  test('pdf invoice generation time', () async {
    final s = await fresh('pdf');
    final c = Client(name: 'شركة طلوع الجزيرة التجارية', phone: '0551234567');
    await s.saveClient(c);
    final inv = mk(c, 1);
    inv.number = s.nextNumber(DocKind.invoice);
    await s.saveDoc(inv);
    final docs = await DocPdf.create(s.org);
    // تسخين (تحميل الخطوط) ثم قياس
    await docs.invoice(inv, const [], client: c);
    final sw = Stopwatch()..start();
    late List<int> bytes;
    for (var i = 0; i < 3; i++) {
      bytes = await docs.invoice(inv, const [], client: c);
    }
    sw.stop();
    results['pdf_invoice_ms'] = sw.elapsedMilliseconds / 3;
    results['pdf_invoice_kb'] = bytes.length ~/ 1024;
    // ignore: avoid_print
    print(
      'pdf invoice avg ${sw.elapsedMilliseconds / 3} ms, ${bytes.length ~/ 1024} KB',
    );
    s.dispose();
  });
}
