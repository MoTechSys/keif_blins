import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keif_diafa/core/models.dart';
import 'package:keif_diafa/pdf/documents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final org = Org();
  final client = Client(id: 'c1', name: 'عميل الضغط', phone: '0500000000');

  test('A: 6 items with very long descriptions (short-card mode) must not throw', () async {
    final inv = Invoice(id: 'a', number: 'INV-A', clientId: 'c1', issueDate: '2026-07-10', status: 'sent', eventDate: '2026-07-12', location: 'قاعة', attendees: '100',
        notes: 'ملاحظة طويلة جدًا ' * 12,
        items: [for (var k = 0; k < 6; k++) LineItem(desc: 'بند $k\n${List.generate(7, (i) => '- تفصيل رقم $i للبند مع نص طويل نسبيًا لملء السطر').join('\n')}', unitPrice: 10000, qty: 1, external: 500)]);
    final s = buildStatement(client: client, invoices: [inv], payments: [], number: 'T');
    final pdf = await DocPdf.create(org);
    final b = await pdf.statementDetailed(s, []);
    expect(b.length, greaterThan(1000));
    await File('build/test_pdfs/stress_a.pdf').writeAsBytes(b);
  });

  test('B: invoice with 60 payments must not throw', () async {
    final inv = Invoice(id: 'b', number: 'INV-B', clientId: 'c1', issueDate: '2026-07-10', status: 'sent', items: [LineItem(desc: 'خدمة', unitPrice: 60000000, qty: 1)]);
    final ps = [for (var k = 0; k < 60; k++) Payment(id: 'p$k', clientId: 'c1', invoiceId: 'b', amount: 100000, date: '2026-07-${(k % 28 + 1).toString().padLeft(2, '0')}', receiptNumber: 'R$k')];
    final s = buildStatement(client: client, invoices: [inv], payments: ps, number: 'T');
    final pdf = await DocPdf.create(org);
    final b = await pdf.statementDetailed(s, ps);
    expect(b.length, greaterThan(1000));
    await File('build/test_pdfs/stress_b.pdf').writeAsBytes(b);
  });

  test('C: 60 on-account payments must not throw', () async {
    final ps = [for (var k = 0; k < 60; k++) Payment(id: 'q$k', clientId: 'c1', invoiceId: '', amount: 1000, date: '2026-07-${(k % 28 + 1).toString().padLeft(2, '0')}', notes: 'ملاحظة $k')];
    final s = buildStatement(client: client, invoices: [], payments: ps, number: 'T');
    final pdf = await DocPdf.create(org);
    final b = await pdf.statementDetailed(s, ps);
    expect(b.length, greaterThan(1000));
  });

  test('D: invoice PDF with 60 items + quotation + receipt long strings', () async {
    final inv = Invoice(id: 'd', number: 'INV-D', clientId: 'c1', issueDate: '2026-07-10', status: 'sent', deposit: 100, vatRateBp: 1500, discount: 50,
        notes: 'ن' * 900, terms: 'ش' * 900,
        items: [for (var k = 0; k < 60; k++) LineItem(desc: 'بند $k\n- تفصيل', unitPrice: 1000 * (k + 1), qty: 2, external: 300)]);
    final pdf = await DocPdf.create(org);
    expect((await pdf.invoice(inv, [], client: client)).length, greaterThan(1000));
    final q = Invoice(id: 'q', kind: DocKind.quotation, number: 'QT-D', clientId: 'c1', issueDate: '2026-07-10', items: inv.items, notes: inv.notes, terms: inv.terms);
    expect((await pdf.invoice(q, [], client: client)).length, greaterThan(1000));
    final p = Payment(id: 'pp', clientId: 'c1', invoiceId: 'd', amount: 123456789, date: '2026-07-11', reference: 'X' * 80, notes: 'م' * 400);
    expect((await pdf.receipt(p, client, inv, payments: [p])).length, greaterThan(1000));
    // سند بلا فاتورة وبعميل بلا هاتف
    final p2 = Payment(id: 'pp2', clientId: 'c1', invoiceId: '', amount: 5, date: '2026-07-11');
    expect((await pdf.receipt(p2, Client(id: 'c1', name: 'x'), null, payments: [p2])).length, greaterThan(1000));
  });

  test('E: empty/edge data: invoice with no items, zero amounts, empty org', () async {
    final pdf = await DocPdf.create(Org()..name = ''..iban = ''..phone = '');
    final inv = Invoice(id: 'e', number: '', clientId: 'c1', issueDate: '2026-07-10', status: 'sent');
    expect((await pdf.invoice(inv, [], client: client)).length, greaterThan(1000));
    final s = buildStatement(client: client, invoices: [inv], payments: [], number: '');
    expect((await pdf.statement(s)).length, greaterThan(1000));
    expect((await pdf.statementDetailed(s, [])).length, greaterThan(1000));
    final s0 = buildStatement(client: client, invoices: [], payments: [], number: '');
    expect((await pdf.statement(s0)).length, greaterThan(1000));
  });
}
