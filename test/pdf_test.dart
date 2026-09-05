import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keif_diafa/core/models.dart';
import 'package:keif_diafa/core/share_service.dart';
import 'package:keif_diafa/pdf/documents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final org = Org();
  final client = Client(id: 'c1', name: 'شركة هنقرستيشن', contact: 'أ. محمد العمري', phone: '0551234567', vatNumber: '300012345600003', address: 'جدة — حي الروضة');
  final inv = Invoice(
    id: 'i1',
    number: 'INV-0042',
    clientId: 'c1',
    clientName: client.name,
    issueDate: '2026-08-04',
    eventDate: '2026-08-12',
    eventDateTo: '2026-08-13',
    location: 'قاعة الماسة — فندق الريتز كارلتون',
    attendees: '120',
    deposit: 500000,
    discount: 50000,
    vatRateBp: 1500, // اختبار مسار الضريبة صراحةً (الافتراضي الآن 0 = بدون ضريبة)
    items: [
      LineItem(desc: 'تجهيز قاعة ضيافة ملكية\nتنسيق طاولات وكراسي فاخرة\nإضاءة ديكورية وزهور طبيعية', unitPrice: 1500000, qty: 1, unitLabel: 'فترة'),
      LineItem(desc: 'بوفيه عشاء مفتوح\nأطباق رئيسية وحلويات ومشروبات', unitPrice: 25000, qty: 120, unitLabel: 'شخص', external: 80000),
      LineItem(desc: 'قهوة عربية وضيافة استقبال', unitPrice: 350000, qty: 2, unitLabel: 'يوم'),
    ],
  );
  final pays = [Payment(id: 'p1', clientId: 'c1', invoiceId: 'i1', amount: 1000000, date: '2026-08-06', method: 'تحويل بنكي', reference: 'TRX-88213', receiptNumber: 'REC-0007')];

  Future<void> save(String name, List<int> bytes) async {
    final dir = Directory('build/test_pdfs')..createSync(recursive: true);
    File('${dir.path}/$name').writeAsBytesSync(bytes);
  }

  test('invoice PDF renders', () async {
    final pdf = await DocPdf.create(org);
    final bytes = await pdf.invoice(inv, pays, client: client);
    expect(bytes.length, greaterThan(20000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    await save('invoice.pdf', bytes);
  });

  test('quotation PDF renders', () async {
    final q = inv.copy()
      ..kind = DocKind.quotation
      ..number = 'QT-0009'
      ..status = 'sent'
      ..validUntil = '2026-08-20'
      ..deposit = 0;
    final pdf = await DocPdf.create(org);
    final bytes = await pdf.invoice(q, [], client: client);
    expect(bytes.length, greaterThan(20000));
    await save('quotation.pdf', bytes);
  });

  test('statement PDF renders multi-page', () async {
    final docs = <Invoice>[];
    final ps = <Payment>[];
    for (var i = 1; i <= 30; i++) {
      final d = '2026-${(i % 12 + 1).toString().padLeft(2, '0')}-${(i % 27 + 1).toString().padLeft(2, '0')}';
      // تنويع البنود ليُثبت الكشف التفصيلي اكتماله: مشتريات خارجية، وصف متعدد الأسطر، وحدات مختلطة، عربون، ملاحظات، وفاتورة طويلة (>6 بنود) لوضع الانقسام
      final items = <LineItem>[LineItem(desc: 'خدمة ضيافة $i', unitPrice: 100000 * i, qty: 1)];
      if (i % 4 == 0) {
        items
          ..add(LineItem(desc: 'ضيافة كاملة لفعالية\n- قهوة عربية وتمور فاخرة\n- عصائر طبيعية ومياه\n- طاقم خدمة 4 أفراد', unitPrice: 250000, qty: 2, unitLabel: 'يوم', external: 80000))
          ..add(LineItem(desc: 'استئجار أدوات تقديم', unitPrice: 15000, qty: 12, unitLabel: 'قطعة', external: 30000));
      }
      if (i == 19) {
        for (var k = 1; k <= 8; k++) {
          items.add(LineItem(desc: 'بند إضافي رقم $k للفعالية الممتدة', unitPrice: 12500 * k, qty: k.toDouble(), unitLabel: 'شخص'));
        }
      }
      docs.add(Invoice(id: 'x$i', number: 'INV-${i.toString().padLeft(4, '0')}', clientId: 'c1', clientName: client.name, issueDate: d, status: 'sent', location: 'قاعة $i',
          eventDate: i % 4 == 0 ? d : '', eventDateTo: i % 8 == 0 ? '2026-${(i % 12 + 1).toString().padLeft(2, '0')}-${(i % 27 + 3).toString().padLeft(2, '0')}' : '',
          attendees: i % 4 == 0 ? '${40 + i}' : '', items: items,
          deposit: i % 4 == 0 ? 150000 : 0,
          notes: i % 6 == 0 ? 'تم التنسيق مع مسؤول الفعالية؛ التوريد قبل الموعد بساعتين.' : '',
          // بعض الفواتير بضريبة/خصم للتحقق من ظهور أعمدة الشرح في الكشف
          vatRateBp: i % 3 == 0 ? 1500 : 0, discount: i % 5 == 0 ? 10000 : 0));
      if (i.isEven) ps.add(Payment(id: 'p$i', clientId: 'c1', invoiceId: 'x$i', amount: 50000 * i, date: d, receiptNumber: 'REC-${i.toString().padLeft(4, '0')}'));
    }
    // دفعة على الحساب (غير مرتبطة بفاتورة) لاختبار ظهورها في حركة الحساب
    ps.add(Payment(id: 'p-acc', clientId: 'c1', invoiceId: '', amount: 250000, date: '2026-06-15', method: 'نقدًا', receiptNumber: 'REC-0100'));
    final s = buildStatement(client: client, invoices: docs, payments: ps, number: 'SOA-202608-001');
    expect(s.rows.length, greaterThanOrEqualTo(45), reason: 'المسودات فقط تُستبعد؛ المرسَلة تظهر');
    // معادلة الكشف: رصيد سابق + فواتير − مدفوعات = الرصيد
    expect(s.closing, s.opening + s.billed - s.paid);
    expect(s.rows.last.balance, s.closing);
    final pdf = await DocPdf.create(org);
    final bytes = await pdf.statement(s);
    expect(bytes.length, greaterThan(20000));
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length, greaterThanOrEqualTo(2), reason: 'multi-page');
    await save('statement.pdf', bytes);

    // كشف لفترة محددة برصيد سابق: يجب أن يُرحَّل ما قبل الفترة إلى «رصيد سابق»
    final s2 = buildStatement(client: client, invoices: docs, payments: ps, from: '2026-07-01', to: '2026-09-30', number: 'SOA-202609-002');
    expect(s2.opening, isNot(0), reason: 'حركات ما قبل يوليو تُرحَّل كرصيد سابق');
    expect(s2.closing, s2.opening + s2.billed - s2.paid);
    await save('statement_period.pdf', await pdf.statement(s2));

    // الكشف التفصيلي: بنود كل فاتورة ودفعاتها + دفعات على الحساب
    final det = await pdf.statementDetailed(s2, ps);
    expect(det.length, greaterThan(20000));
    await save('statement_detailed.pdf', det);
  });

  test('receipt PDF renders', () async {
    final pdf = await DocPdf.create(org);
    final bytes = await pdf.receipt(pays.first, client, inv, payments: pays);
    expect(bytes.length, greaterThan(10000));
    await save('receipt.pdf', bytes);
    // سند على الحساب بلا فاتورة + بمرجع وملاحظات
    final acc = Payment(id: 'p9', clientId: 'c1', invoiceId: '', amount: 350000, date: '2026-08-10', method: 'نقدًا', reference: 'CASH-01', notes: 'دفعة مقدمة لمناسبة سبتمبر', receiptNumber: 'REC-0009');
    await save('receipt_account.pdf', await pdf.receipt(acc, client, null, payments: pays));
  });

  test('share messages', () {
    final m = ShareService.invoiceMessage(inv, org, pays);
    expect(m, contains('INV-0042'));
    expect(m, contains('IBAN'));
    expect(m, contains('المتبقي'));
    final q = ShareService.invoiceMessage(inv.copy()..kind = DocKind.quotation, org, []);
    expect(q, contains('عرض السعر'));
    expect(ShareService.safeName('INV/00:1'), 'INV-00-1');
  });
}
