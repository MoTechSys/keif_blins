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
      docs.add(Invoice(id: 'x$i', number: 'INV-${i.toString().padLeft(4, '0')}', clientId: 'c1', clientName: client.name, issueDate: d, status: 'sent', location: 'قاعة $i', items: [LineItem(desc: 'خدمة ضيافة $i', unitPrice: 100000 * i, qty: 1)],
          // بعض الفواتير بضريبة/خصم للتحقق من ظهور أعمدة الشرح في الكشف
          vatRateBp: i % 3 == 0 ? 1500 : 0, discount: i % 5 == 0 ? 10000 : 0));
      if (i.isEven) ps.add(Payment(id: 'p$i', clientId: 'c1', invoiceId: 'x$i', amount: 50000 * i, date: d, receiptNumber: 'REC-${i.toString().padLeft(4, '0')}'));
    }
    final s = buildStatement(client: client, invoices: docs, payments: ps, number: 'SOA-202608-001');
    expect(s.rows.length, greaterThanOrEqualTo(45), reason: 'المسودات فقط تُستبعد؛ المرسَلة تظهر');
    final pdf = await DocPdf.create(org);
    final bytes = await pdf.statement(s);
    expect(bytes.length, greaterThan(20000));
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length, greaterThanOrEqualTo(2), reason: 'multi-page');
    await save('statement.pdf', bytes);
  });

  test('receipt PDF renders', () async {
    final pdf = await DocPdf.create(org);
    final bytes = await pdf.receipt(pays.first, client, inv);
    expect(bytes.length, greaterThan(10000));
    await save('receipt.pdf', bytes);
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
