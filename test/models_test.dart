import 'package:flutter_test/flutter_test.dart';
import 'package:keif_diafa/core/models.dart';

Invoice _inv({String id = 'i1', String client = 'c1', int deposit = 0, int vat = 1500, int discount = 0, String date = '2026-08-04', String status = 'issued'}) =>
    Invoice(
      id: id,
      clientId: client,
      issueDate: date,
      status: status,
      vatRateBp: vat,
      discount: discount,
      deposit: deposit,
      items: [
        LineItem(desc: 'قاعة', unitPrice: 1500000, qty: 1, external: 0),
        LineItem(desc: 'بوفيه', unitPrice: 25000, qty: 120, external: 80000),
      ],
    );

void main() {
  test('line item math', () {
    final li = LineItem(unitPrice: 12345, qty: 1.5, external: 100);
    expect(li.service, 18518); // 18517.5 -> 18518
    expect(li.total, 18618);
  });

  test('invoice totals with VAT, discount, external', () {
    final t = _inv(discount: 100000).totals;
    expect(t.services, 1500000 + 3000000);
    expect(t.external, 80000);
    expect(t.subtotal, 4580000);
    expect(t.discount, 100000);
    expect(t.vat, 672000); // 4,480,000 * 15%
    expect(t.total, 5152000);
  });

  test('discount cannot exceed subtotal', () {
    final t = _inv(discount: 99999999).totals;
    expect(t.total, 0);
  });

  test('status computation', () {
    final inv = _inv(deposit: 500000);
    final total = inv.totals.total;
    expect(computeStatus(inv, []), InvoiceStatus.partial);
    expect(computeStatus(inv, [Payment(invoiceId: 'i1', clientId: 'c1', amount: total - 500000)]), InvoiceStatus.paid);
    expect(computeStatus(_inv(), []), InvoiceStatus.issued);
    expect(computeStatus(_inv(status: 'draft'), []), InvoiceStatus.draft);
    expect(invoiceRemaining(inv, []), total - 500000);
  });

  test('client summary excludes drafts and cancelled', () {
    final c = Client(id: 'c1', name: 'هنقرستيشن', openingBalance: 10000);
    final docs = [_inv(id: 'a', deposit: 100000), _inv(id: 'b', status: 'draft'), _inv(id: 'c', status: 'cancelled')];
    final pays = [
      Payment(clientId: 'c1', invoiceId: 'a', amount: 50000),
      Payment(clientId: 'c1', invoiceId: 'b', amount: 99999), // على مسودة — تُستثنى
      Payment(clientId: 'c1', invoiceId: '', amount: 20000), // على الحساب
    ];
    final s = clientSummary(c, docs, pays);
    expect(s.invoiceCount, 1);
    expect(s.billed, docs[0].totals.total);
    expect(s.deposits, 100000);
    expect(s.payments, 70000);
    expect(s.outstanding, 10000 + docs[0].totals.total - 170000);
    expect(s.unpaidCount, 1);
  });

  test('statement running balance and period opening', () {
    final c = Client(id: 'c1', name: 'عميل', openingBalance: 100000);
    final docs = [
      _inv(id: 'old', date: '2026-06-10', deposit: 200000),
      _inv(id: 'cur', date: '2026-08-04'),
    ];
    final pays = [
      Payment(clientId: 'c1', invoiceId: 'old', amount: 100000, date: '2026-06-20'),
      Payment(clientId: 'c1', invoiceId: 'cur', amount: 300000, date: '2026-08-10', receiptNumber: 'REC-0001'),
    ];
    final s = buildStatement(client: c, invoices: docs, payments: pays, from: '2026-08-01', to: '2026-08-31', number: 'SOA-202608-001');
    final oldTotal = docs[0].totals.total;
    expect(s.opening, 100000 + oldTotal - 200000 - 100000);
    expect(s.rows.length, 2); // فاتورة + دفعة
    expect(s.rows.first.type, 'invoice');
    expect(s.rows.last.credit, 300000);
    expect(s.closing, s.opening + docs[1].totals.total - 300000);
    expect(s.billed, docs[1].totals.total);
    expect(s.paid, 300000);
    expect(s.count, 1);
    // كل الفترات
    final all = buildStatement(client: c, invoices: docs, payments: pays);
    expect(all.opening, 100000);
    expect(all.rows.length, 5); // فاتورتان + عربون + دفعتان
    expect(all.closing, s.closing);
  });

  test('quotation excluded from ledger and serializes', () {
    final q = Invoice(kind: DocKind.quotation, clientId: 'c1', status: 'sent', items: [LineItem(desc: 'x', unitPrice: 100)]);
    expect(q.countsInLedger, false);
    final back = Invoice.fromMap(q.toMap());
    expect(back.isQuote, true);
    expect(back.totals.total, q.totals.total);
    expect(back.quoteStatus, QuoteStatus.sent);
  });

  test('fmtDate', () {
    expect(fmtDate('2026-08-04'), '2026/8/4');
    expect(fmtMonth('2026-08-04'), 'أغسطس 2026');
  });

  test('Org iban spacing and defaults', () {
    final o = Org.fromMap(null);
    expect(o.ibanSpaced, 'SA73 1000 0001 4000 1724 4409');
    expect(o.name, 'مؤسسة كيف الضيافة');
  });
}
